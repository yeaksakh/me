import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warehouse/data/auth_api.dart';
import 'package:warehouse/models/staff.dart';

/// A successful login, shaped the way mekhea-py `core/api/views_login.py`
/// answers it.
Map<String, dynamic> loginAnswer({
  bool isAdmin = false,
  String name = 'Sokha Chan',
}) =>
    {
      'success': true,
      'data': {
        'token': 'tok-123',
        'token_type': 'Bearer',
        'expires_at': '2026-12-09T00:00:00+00:00',
        'user': {
          'id': 42,
          'username': 'sokha',
          'name': name,
          'surname': null,
          'first_name': 'Sokha',
          'last_name': 'Chan',
          'email': null,
          'language': 'en',
        },
        'business': {'id': 3, 'name': 'Yeaksa Shop'},
        'is_admin': isAdmin,
      },
    };

AuthApi apiAnswering(http.Response Function(http.Request request) answer) =>
    AuthApi(httpClient: MockClient((request) async => answer(request)));

Matcher throwsAuthMessage(Object message) =>
    throwsA(isA<AuthException>().having((e) => e.message, 'message', message));

void main() {
  test('posts the username and password to /api/auth/login', () async {
    late http.Request sent;
    final api = apiAnswering((request) {
      sent = request;
      return http.Response(jsonEncode(loginAnswer()), 200);
    });

    final result = await api.signIn(username: 'sokha', password: 'pa ss');

    expect(sent.method, 'POST');
    expect(sent.url.toString(), 'https://yeaksa.com/api/auth/login');
    final body = jsonDecode(sent.body) as Map<String, dynamic>;
    expect(body['username'], 'sokha');
    expect(body['password'], 'pa ss');
    expect(result.token, 'tok-123');
    expect(result.staff.id, '42');
    expect(result.staff.name, 'Sokha Chan');
    expect(result.staff.username, 'sokha');
    expect(result.staff.warehouseName, 'Yeaksa Shop');
  });

  test('an admin signs in as a supervisor, anyone else as a packer', () async {
    final admin = await apiAnswering(
            (_) => http.Response(jsonEncode(loginAnswer(isAdmin: true)), 200))
        .signIn(username: 'a', password: 'b');
    final staff =
        await apiAnswering((_) => http.Response(jsonEncode(loginAnswer()), 200))
            .signIn(username: 'a', password: 'b');

    expect(admin.staff.role, StaffRole.supervisor);
    expect(staff.staff.role, StaffRole.packer);
  });

  test('a blank name falls back to the username', () {
    final data = loginAnswer(name: ' ')['data'] as Map<String, dynamic>;
    expect(staffFromLogin(data).name, 'sokha');
  });

  test('a wrong password shows the server message', () async {
    final api = apiAnswering((_) => http.Response(
        jsonEncode({
          'success': false,
          'error': 'bad_credentials',
          'message': 'Wrong username or password.',
        }),
        401));

    await expectLater(api.signIn(username: 'x', password: 'y'),
        throwsAuthMessage('Wrong username or password.'));
  });

  test('a success with no token is not a session', () async {
    final api = apiAnswering(
        (_) => http.Response(jsonEncode({'success': true, 'data': {}}), 200));

    await expectLater(api.signIn(username: 'x', password: 'y'),
        throwsAuthMessage('The server did not return a session. Try again.'));
  });

  test('an HTML error page is reported, not thrown raw', () async {
    final api = apiAnswering((_) => http.Response('<html>502</html>', 502));

    await expectLater(api.signIn(username: 'x', password: 'y'),
        throwsAuthMessage('The server sent something the app could not read.'));
  });

  test('no connection is reported as such', () async {
    final api = AuthApi(
        httpClient: MockClient(
            (_) async => throw http.ClientException('Failed host lookup')));

    await expectLater(api.signIn(username: 'x', password: 'y'),
        throwsAuthMessage(contains('Could not reach the server')));
  });

  test('signing out revokes this token', () async {
    late http.Request sent;
    final api = apiAnswering((request) {
      sent = request;
      return http.Response(
          jsonEncode({
            'success': true,
            'data': {'message': 'Signed out.'},
          }),
          200);
    });

    await api.signOut('tok-123');

    expect(sent.url.path, '/api/auth/logout');
    expect(sent.headers['Authorization'], 'Bearer tok-123');
  });

  test('each request goes to the server chosen at that moment', () async {
    var server = 'https://yeaksa.com';
    final urls = <String>[];
    final api = AuthApi(
      baseUrl: () => server,
      httpClient: MockClient((request) async {
        urls.add(request.url.toString());
        return http.Response(jsonEncode(loginAnswer()), 200);
      }),
    );

    await api.signIn(username: 'a', password: 'b');
    server = 'http://192.168.1.10:8000';
    await api.signIn(username: 'a', password: 'b');

    expect(urls, [
      'https://yeaksa.com/api/auth/login',
      'http://192.168.1.10:8000/api/auth/login',
    ]);
  });
}
