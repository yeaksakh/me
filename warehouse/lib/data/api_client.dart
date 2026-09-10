import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../state/server_config.dart';

/// A request that did not produce a usable answer.
///
/// Carries a message already fit to show: the screens display [message] rather
/// than composing their own, so a wording change happens in one place.
class ApiException implements Exception {
  ApiException(this.message, {this.status, this.code});

  final String message;

  /// The HTTP status, when the server answered at all.
  final int? status;

  /// The server's machine-readable reason, e.g. `already_in`.
  final String? code;

  /// The session is gone -- revoked, expired, or the account was switched off.
  bool get isUnauthorized => status == 401;

  @override
  String toString() => message;
}

/// The HTTP layer for the staff API (`/api/*` on the shop's server).
///
/// Thin and free of app state: it is handed the server address and the token
/// by whoever builds it, both read on every request, so a server changed on the
/// sign-in screen or a fresh sign-in is used at once.
class ApiClient {
  ApiClient({
    String Function()? baseUrl,
    String? Function()? token,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 20),
  })  : _baseUrl = baseUrl ?? (() => ServerConfig.defaultUrl),
        _token = token ?? (() => null),
        _http = httpClient ?? http.Client();

  final String Function() _baseUrl;
  final String? Function() _token;
  final Duration timeout;
  final http.Client _http;

  Map<String, String> _headers({bool json = false}) {
    final token = _token();
    return {
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${_baseUrl()}$path').replace(queryParameters: query);

  Future<Map<String, dynamic>> get(String path,
          {Map<String, String>? query}) =>
      _send(() => _http.get(_uri(path, query), headers: _headers()));

  Future<Map<String, dynamic>> post(String path,
          [Map<String, Object?>? body]) =>
      _send(() => _http.post(_uri(path),
          headers: _headers(json: true), body: jsonEncode(body ?? const {})));

  /// A form post that may carry one file -- what a photo needs, since it
  /// cannot go through `jsonEncode`.
  Future<Map<String, dynamic>> postMultipart(
    String path,
    Map<String, String> fields, {
    String? fileField,
    String? filePath,
  }) =>
      _send(() async {
        final request = http.MultipartRequest('POST', _uri(path))
          ..headers.addAll(_headers())
          ..fields.addAll(fields);
        if (fileField != null && filePath != null) {
          request.files
              .add(await http.MultipartFile.fromPath(fileField, filePath));
        }
        return http.Response.fromStream(await _http.send(request));
      });

  /// Runs a request and turns anything that is not a well-formed success into
  /// an [ApiException] with a sentence the person can act on.
  Future<Map<String, dynamic>> _send(
      Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(timeout);
    } on TimeoutException {
      throw ApiException('The server took too long to answer. Try again.');
    } on Exception {
      throw ApiException(
          'Could not reach the server. Check your internet and try again.');
    }

    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) body = decoded;
    } on FormatException {
      // An HTML page; reported below.
    }
    if (body == null) {
      throw ApiException(
        response.statusCode == 404
            ? 'This server does not have that yet. Check the server address.'
            : 'The server sent something the app could not read.',
        status: response.statusCode,
      );
    }
    if (body['success'] != true) {
      throw ApiException(
        (body['message'] as String?) ?? 'Something went wrong.',
        status: response.statusCode,
        code: body['error'] as String?,
      );
    }
    return body;
  }
}
