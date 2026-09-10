import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/fulfilment_stage.dart';
import '../models/order.dart';
import '../state/server_config.dart';

/// A shipment request that did not work, with a message fit to show as is.
class ShipmentsException implements Exception {
  ShipmentsException(this.message, {this.status, this.code});

  final String message;

  /// The HTTP status, when the server answered at all.
  final int? status;

  /// The server's machine-readable reason, e.g. `taken` or `items_not_packed`.
  final String? code;

  /// The session is gone -- revoked, expired, or the account was switched off.
  bool get isUnauthorized => status == 401;

  @override
  String toString() => message;
}

/// One tab's worth of shipments, and how many sit at every status.
class ShipmentPage {
  const ShipmentPage({required this.orders, required this.counts});

  final List<Order> orders;
  final Map<FulfilmentStage, int> counts;
}

/// The website's /shipments page, for this app: `core/api/views_shipments.py`.
///
/// Every call carries the Bearer token from `/api/auth/login`, so the server
/// applies that person's own permissions and records them as the one who
/// accepted, packed or moved each shipment.
class ShipmentsApi {
  ShipmentsApi({
    String Function()? baseUrl,
    String? Function()? token,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 20),
  })  : _baseUrl = baseUrl ?? (() => ServerConfig.defaultUrl),
        _token = token ?? (() => null),
        _http = httpClient ?? http.Client();

  /// Both read on every request, so a changed server or a new sign-in is used
  /// at once.
  final String Function() _baseUrl;
  final String? Function() _token;
  final Duration timeout;
  final http.Client _http;

  /// Shipments at [stage], newest first, as the website lists them.
  ///
  /// Not oldest first, although a queue is worked front to back: the live book
  /// holds thousands of `ordered` sales going back years that nobody will ever
  /// pack, and oldest first put those at the top of every shift.
  Future<ShipmentPage> list(FulfilmentStage stage, {int limit = 100}) async {
    final body = await _send('GET', '/api/shipments', query: {
      'status': stage.apiValue,
      'limit': '$limit',
    });
    final counts = <FulfilmentStage, int>{};
    final raw = body['counts'];
    if (raw is Map) {
      raw.forEach((key, value) {
        final status = stageFromApiOrNull(key);
        if (status != null && value is num) counts[status] = value.toInt();
      });
    }
    final rows = body['data'];
    return ShipmentPage(
      orders: rows is List
          ? rows.whereType<Map<String, dynamic>>().map(Order.fromApi).toList()
          : const [],
      counts: counts,
    );
  }

  /// One shipment with its items, who packed each, and its photos.
  Future<Order> detail(String id) async =>
      _order(await _send('GET', '/api/shipments/$id'));

  /// Take an ordered shipment to pack.
  Future<Order> accept(String id) async =>
      _order(await _send('POST', '/api/shipments/$id/accept'));

  /// Hand back a shipment accepted by mistake, before anything is ticked.
  Future<Order> release(String id) async =>
      _order(await _send('POST', '/api/shipments/$id/release'));

  /// Tick an item into the box, or untick it.
  Future<Order> packLine(String id, String lineId,
          {required bool packed}) async =>
      _order(await _send('POST', '/api/shipments/$id/lines/$lineId/pack',
          body: {'packed': packed}));

  /// Move a shipment on: to `packed`, or to `audited`.
  Future<Order> setStatus(String id, FulfilmentStage stage) async =>
      _order(await _send('POST', '/api/shipments/$id/status',
          body: {'status': stage.apiValue}));

  Order _order(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw ShipmentsException(
          'The server sent something the app could not read.');
    }
    return Order.fromApi(data);
  }

  /// Sends one request and returns the body of a `{"success": true}` answer.
  ///
  /// Failures arrive as `{"success": false, "message": ...}` with a real HTTP
  /// status, and the message is already written for the person holding the
  /// phone -- "Already accepted by Sok Dara." -- so it is shown as it comes.
  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
  }) async {
    final uri = Uri.parse('${_baseUrl()}$path').replace(queryParameters: query);
    final token = _token();
    final headers = {
      'Accept': 'application/json',
      if (method != 'GET') 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final http.Response response;
    try {
      final request = method == 'GET'
          ? _http.get(uri, headers: headers)
          : _http.post(uri,
              headers: headers, body: jsonEncode(body ?? const {}));
      response = await request.timeout(timeout);
    } on TimeoutException {
      throw ShipmentsException(
          'The server took too long to answer. Pull down to try again.');
    } on Exception {
      throw ShipmentsException(
          'Could not reach the server. Check your internet and try again.');
    }

    Map<String, dynamic>? decoded;
    try {
      final value = jsonDecode(utf8.decode(response.bodyBytes));
      if (value is Map<String, dynamic>) decoded = value;
    } on FormatException {
      // An HTML page; reported below.
    }
    if (decoded == null) {
      throw ShipmentsException(
        response.statusCode == 404
            // The likeliest cause: a server that has not been given these
            // endpoints yet, or the wrong server address.
            ? 'This server has no shipments API yet. Check the server address.'
            : 'The server sent something the app could not read.',
        status: response.statusCode,
      );
    }
    if (decoded['success'] != true) {
      throw ShipmentsException(
        (decoded['message'] as String?) ?? 'Something went wrong.',
        status: response.statusCode,
        code: decoded['error'] as String?,
      );
    }
    return decoded;
  }
}
