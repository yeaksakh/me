import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warehouse/app.dart';
import 'package:warehouse/data/local_store.dart';
import 'package:warehouse/screens/login_screen.dart';
import 'package:warehouse/state/server_config.dart';

import 'fixtures.dart';

/// Pumps the app on its sign-in screen, off the network.
Future<void> pumpLogin(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    WarehouseApp(
      repository: repositoryWith(),
      auth: FakeAuthApi(),
      watchForNewOrders: false,
    ),
  );
  await tester.pumpAndSettle();
}

/// Taps the sign-in logo [times] in a row, staying inside the tap window.
Future<void> tapLogo(WidgetTester tester, int times) async {
  final logo = find.byKey(LoginScreen.logoKey);
  for (var i = 0; i < times; i++) {
    await tester.tap(logo);
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ServerConfig.normalise', () {
    test('keeps a full https address', () {
      expect(
          ServerConfig.normalise('https://yeaksa.com'), 'https://yeaksa.com');
    });

    test('treats a bare host as https', () {
      expect(ServerConfig.normalise('yeaksa.com'), 'https://yeaksa.com');
    });

    test('keeps an explicit http scheme and port', () {
      expect(
        ServerConfig.normalise('http://192.168.1.10:8000'),
        'http://192.168.1.10:8000',
      );
    });

    test('trims whitespace and trailing slashes', () {
      expect(
        ServerConfig.normalise('  https://staging.yeaksa.com//  '),
        'https://staging.yeaksa.com',
      );
    });

    test('drops query and fragment so a path can be appended', () {
      expect(
        ServerConfig.normalise('https://yeaksa.com/api?debug=1#top'),
        'https://yeaksa.com/api',
      );
    });

    test('rejects empty text and non-http schemes', () {
      expect(ServerConfig.normalise(''), isNull);
      expect(ServerConfig.normalise('   '), isNull);
      expect(ServerConfig.normalise('ftp://yeaksa.com'), isNull);
    });

    test('rejects prose rather than percent-encoding it into a host', () {
      expect(ServerConfig.normalise('not a url at all'), isNull);
      expect(ServerConfig.normalise('https://two words.com'), isNull);
    });
  });

  group('ServerConfig', () {
    test('starts on https://yeaksa.com', () {
      final config = ServerConfig();
      expect(config.baseUrl, 'https://yeaksa.com');
      expect(config.isDefault, isTrue);
    });

    test('a rejected address is reported and leaves the server alone',
        () async {
      final config = ServerConfig();

      final problem = await config.setBaseUrl('ftp://yeaksa.com');

      expect(problem, isNotNull);
      expect(config.baseUrl, 'https://yeaksa.com');
    });

    test('a saved server survives a restart', () async {
      await ServerConfig(store: LocalStore()).setBaseUrl('staging.yeaksa.com');

      final restored = ServerConfig(store: LocalStore());
      await Future<void>.delayed(Duration.zero);

      expect(restored.baseUrl, 'https://staging.yeaksa.com');
      expect(restored.isDefault, isFalse);
    });

    test('a stored address that no longer parses is ignored', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.wh_server_url_v1': 'not a url at all',
      });

      final config = ServerConfig(store: LocalStore());
      await Future<void>.delayed(Duration.zero);

      expect(config.baseUrl, 'https://yeaksa.com');
    });

    test('a debug build may be repointed', () {
      // The whole switcher, and the tests below it, depend on this. Guarded so
      // that if `canOverride` is ever tightened, the reason the other tests
      // start failing is stated here rather than inferred.
      expect(ServerConfig.canOverride, isTrue,
          reason: 'tests run in debug, where the override is allowed');
    });

    test('resetting returns to the default', () async {
      final config = ServerConfig(store: LocalStore());
      await config.setBaseUrl('staging.yeaksa.com');

      await config.resetToDefault();

      expect(config.baseUrl, 'https://yeaksa.com');
      expect(config.isDefault, isTrue);
    });
  });

  group('Hidden server picker', () {
    testWidgets('stays shut for fewer than three taps', (tester) async {
      await pumpLogin(tester);

      await tapLogo(tester, 2);

      expect(find.text('Server'), findsNothing);
    });

    testWidgets('three taps open it on the current server', (tester) async {
      await pumpLogin(tester);

      await tapLogo(tester, 3);

      expect(find.text('Server'), findsOneWidget);
      expect(
          find.widgetWithText(TextField, 'https://yeaksa.com'), findsOneWidget);
    });

    testWidgets('saving a new address shows it on the sign-in screen',
        (tester) async {
      await pumpLogin(tester);
      await tapLogo(tester, 3);

      await tester.enterText(
        find.widgetWithText(TextField, 'https://yeaksa.com'),
        'staging.yeaksa.com',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Server'), findsNothing);
      expect(find.text('https://staging.yeaksa.com'), findsOneWidget);
    });

    testWidgets('a bad address is rejected without closing', (tester) async {
      await pumpLogin(tester);
      await tapLogo(tester, 3);

      await tester.enterText(
        find.widgetWithText(TextField, 'https://yeaksa.com'),
        'ftp://yeaksa.com',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Server'), findsOneWidget);
      expect(find.textContaining('Enter a full address'), findsOneWidget);
    });

    testWidgets('use default puts https://yeaksa.com back', (tester) async {
      await pumpLogin(tester);
      await tapLogo(tester, 3);

      await tester.enterText(
        find.widgetWithText(TextField, 'https://yeaksa.com'),
        'staging.yeaksa.com',
      );
      await tester.tap(find.text('Use default'));
      await tester.pumpAndSettle();

      expect(
          find.widgetWithText(TextField, 'https://yeaksa.com'), findsOneWidget);
    });

    testWidgets('cancelling leaves the server unchanged', (tester) async {
      await pumpLogin(tester);
      await tapLogo(tester, 3);

      await tester.enterText(
        find.widgetWithText(TextField, 'https://yeaksa.com'),
        'staging.yeaksa.com',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('https://staging.yeaksa.com'), findsNothing);
    });
  });
}
