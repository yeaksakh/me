import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/staff.dart';
import '../state/server_config.dart';

/// A sign-in or sign-out that did not work, with a message fit to show as is.
class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// What a successful sign-in yields.
class SignInResult {
  const SignInResult({required this.token, required this.staff});

  final String token;
  final Staff staff;
}

/// Staff sign-in against the shop's server.
///
/// `POST /api/auth/login` trades the username and password of a yeaksa.com
/// staff account for a bearer token (mekhea-py `core/api/views_login.py`). The
/// token carries no authority of its own: the server checks that person's
/// permissions on every call, so it can never do more than they could by
/// signing in to the website.
class AuthApi {
  AuthApi({
    String Function()? baseUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 20),
  })  : _baseUrl = baseUrl ?? (() => ServerConfig.defaultUrl),
        _http = httpClient ?? http.Client();

  /// Origin only, no trailing slash. Read on every request rather than
  /// captured, so a server changed on the sign-in screen is the one the next
  /// sign-in goes to.
  final String Function() _baseUrl;
  final Duration timeout;
  final http.Client _http;

  Future<SignInResult> signIn({
    required String username,
    required String password,
  }) async {
    final body = await _post('/api/auth/login', {
      'username': username,
      'password': password,
      // Names the token on the owner's Settings -> API page, so a lost
      // handset's session can be found and revoked there.
      'device_name':
          'Yeaksarehouse (${kIsWeb ? 'web' : defaultTargetPlatform.name})',
    });

    final data = body['data'];
    if (data is! Map<String, dynamic> || data['token'] is! String) {
      // A yes with no session is a server bug; failing here beats signing in
      // to a state where every later call is refused.
      throw AuthException('The server did not return a session. Try again.');
    }
    return SignInResult(
      token: data['token'] as String,
      staff: staffFromLogin(data),
    );
  }

  /// Revokes [token] on the server.
  Future<void> signOut(String token) async {
    await _post('/api/auth/logout', const {}, token: token);
  }

  /// Sends a JSON POST and returns the body of a `{"success": true}` answer.
  ///
  /// Failures arrive as `{"success": false, "message": ...}`, with a 401 for a
  /// wrong username or password, and that message is already written for the
  /// person at the login screen.
  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, Object?> payload, {
    String? token,
  }) async {
    final http.Response response;
    try {
      response = await _http
          .post(
            Uri.parse('${_baseUrl()}$path'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw AuthException('The server took too long to answer. Try again.');
    } on Exception {
      throw AuthException(
          'Could not reach the server. Check your internet and try again.');
    }

    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) body = decoded;
    } on FormatException {
      // An HTML error page; reported below.
    }
    if (body == null) {
      throw AuthException('The server sent something the app could not read.');
    }
    if (body['success'] != true) {
      throw AuthException(
          (body['message'] as String?) ?? 'Sign-in failed. Try again.');
    }
    return body;
  }
}

/// The signed-in person, from the `data` of a login answer.
///
/// The server says who someone is and whether they administer the shop, but has
/// no packer / checker split yet. Admins get supervisor and everyone else packer
/// until it does -- the narrower role, so nobody is handed a sign-off the shop
/// never gave them.
@visibleForTesting
Staff staffFromLogin(Map<String, dynamic> data) {
  final user = data['user'] is Map<String, dynamic>
      ? data['user'] as Map<String, dynamic>
      : const <String, dynamic>{};
  final business = data['business'] is Map<String, dynamic>
      ? data['business'] as Map<String, dynamic>
      : const <String, dynamic>{};
  final username = user['username'] as String?;
  final name = (user['name'] as String?)?.trim();

  return Staff(
    id: '${user['id']}',
    name: (name == null || name.isEmpty) ? (username ?? 'Staff') : name,
    role: data['is_admin'] == true ? StaffRole.supervisor : StaffRole.packer,
    warehouseName: (business['name'] as String?) ?? '',
    username: username,
    currencySymbol: (business['symbol'] as String?)?.trim().isNotEmpty == true
        ? (business['symbol'] as String).trim()
        : r'$',
  );
}
