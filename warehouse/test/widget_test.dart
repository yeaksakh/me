import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse/app.dart';
import 'package:warehouse/models/fulfilment_stage.dart';
import 'package:warehouse/models/order.dart';

import 'fixtures.dart';

/// Pumps the app on a phone-width but very tall surface.
///
/// Width stays phone-sized so the layout under test is the real one; the height
/// is stretched so a screen's whole ListView is built at once and a finder does
/// not miss a widget merely because it is below the fold.
Future<void> pumpApp(WidgetTester tester, {List<Order>? orders}) async {
  tester.view.physicalSize = const Size(420, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    WarehouseApp(
      repository: repositoryWith(),
      auth: FakeAuthApi(),
      shipments: FakeShipmentsApi(orders: orders),
    ),
  );
  await tester.pumpAndSettle();
}

/// Taps a bottom-tab destination.
///
/// Scoped to the NavigationBar on purpose: several of these icons also appear
/// inside cards on the page behind it, and an unscoped byIcon finds both.
Future<void> openTab(WidgetTester tester, IconData icon) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.byIcon(icon),
    ),
  );
  await tester.pumpAndSettle();
}

/// Taps a shipment tab by its label. Scoped to the TabBar: the same word is on
/// the status chip of every card in that tab.
Future<void> openQueue(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(TabBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

Future<void> openShipment(WidgetTester tester, String code) async {
  await tester.tap(find.text(code));
  await tester.pumpAndSettle();
}

/// Types a username and password into the sign-in screen and submits.
Future<void> submitSignIn(
  WidgetTester tester, {
  String username = 'sokha',
  String password = 'secret',
}) async {
  await tester.enterText(find.byType(TextField).at(0), username);
  await tester.enterText(find.byType(TextField).at(1), password);
  await tester.tap(find.text('Sign in'));
  await tester.pumpAndSettle();
}

/// Pumps the app with fixtures and signs in, which every screen sits behind.
Future<void> signIn(WidgetTester tester, {List<Order>? orders}) async {
  await pumpApp(tester, orders: orders);
  await submitSignIn(tester);
}

void main() {
  testWidgets('the app opens on the sign-in screen', (tester) async {
    await pumpApp(tester);

    expect(find.text('Warehouse'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('a wrong password is refused with the server message',
      (tester) async {
    await pumpApp(tester);

    await submitSignIn(tester, password: 'nope');

    expect(find.text('Wrong username or password.'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('an empty password is refused before asking the server',
      (tester) async {
    await pumpApp(tester);

    await submitSignIn(tester, password: '');

    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets("signing in lands on the website's three shipment tabs",
      (tester) async {
    await signIn(tester);

    for (final label in ['Ordered', 'Packed', 'Audited']) {
      expect(
        find.descendant(of: find.byType(TabBar), matching: find.text(label)),
        findsOneWidget,
      );
    }
    expect(find.text('YK-1'), findsOneWidget);
    expect(find.text('Not accepted'), findsOneWidget);
  });

  testWidgets('an empty tab says so in its own words', (tester) async {
    await signIn(tester, orders: [
      buildOrder(id: '1', stage: FulfilmentStage.audited),
    ]);

    expect(find.text('Nothing to pack'), findsOneWidget);
  });

  testWidgets('a shipment nobody has accepted offers Accept, and no ticking',
      (tester) async {
    await signIn(tester);
    await openShipment(tester, 'YK-1');

    expect(find.text('Not accepted yet'), findsOneWidget);
    expect(find.text('Accept to pack'), findsOneWidget);
    expect(find.text('Mark packed'), findsNothing);
    expect(find.text('Scan or type a SKU'), findsNothing);
  });

  testWidgets('accepting unlocks the scan box and Mark packed', (tester) async {
    await signIn(tester);
    await openShipment(tester, 'YK-1');

    await tester.tap(find.text('Accept to pack'));
    await tester.pumpAndSettle();

    expect(find.text('Scan or type a SKU'), findsOneWidget);
    expect(find.text('Mark packed'), findsOneWidget);
    expect(find.text('Hand back'), findsOneWidget);
  });

  testWidgets('ticking every item and marking packed moves it to Packed',
      (tester) async {
    await signIn(tester, orders: [
      buildOrder(
        id: '1',
        preparedById: supervisor.id,
        lines: [buildLine(quantity: 1)],
      ),
    ]);
    await openShipment(tester, 'YK-1');

    expect(find.text('0 / 1 packed'), findsOneWidget);
    await tester.tap(find.text('Widget'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 1 packed'), findsOneWidget);

    await tester.tap(find.text('Mark packed'));
    await tester.pumpAndSettle();

    expect(find.textContaining('packed — waiting for audit'), findsOneWidget);
    await openQueue(tester, 'Packed');
    expect(find.text('YK-1'), findsOneWidget);
  });

  testWidgets('scanning a SKU ticks its item', (tester) async {
    await signIn(tester, orders: [
      buildOrder(
        id: '1',
        preparedById: supervisor.id,
        lines: [buildLine(quantity: 1)],
      ),
    ]);
    await openShipment(tester, 'YK-1');

    await tester.enterText(find.byType(TextField).first, 'SKU-1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('1 / 1 packed'), findsOneWidget);
  });

  testWidgets('a code from another shipment is reported', (tester) async {
    await signIn(tester, orders: [
      buildOrder(id: '1', preparedById: supervisor.id),
    ]);
    await openShipment(tester, 'YK-1');

    await tester.enterText(find.byType(TextField).first, 'NOPE');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.textContaining('is not on this shipment'), findsOneWidget);
  });

  testWidgets("someone else's shipment says who is packing it", (tester) async {
    await signIn(tester, orders: [
      buildOrder(id: '1', preparedById: 'x9', preparedByName: 'Chan Vy'),
    ]);

    expect(find.text('With Chan Vy'), findsOneWidget);
    await openShipment(tester, 'YK-1');

    expect(find.text('Being packed by Chan Vy'), findsOneWidget);
    expect(find.text('Accept to pack'), findsNothing);
    expect(find.text('Mark packed'), findsNothing);
  });

  testWidgets('a packed shipment can be marked audited by a supervisor',
      (tester) async {
    await signIn(tester, orders: [
      buildOrder(
        id: '1',
        stage: FulfilmentStage.packed,
        lines: [buildLine(quantity: 1, packed: true)],
      ),
    ]);
    await openQueue(tester, 'Packed');
    await openShipment(tester, 'YK-1');

    await tester.tap(find.text('Mark audited'));
    await tester.pumpAndSettle();

    expect(find.textContaining('audited — waiting for the rider'), findsOneWidget);
    await openQueue(tester, 'Audited');
    expect(find.text('YK-1'), findsOneWidget);
  });

  testWidgets('an audited shipment waits for the rider', (tester) async {
    await signIn(tester, orders: [
      buildOrder(id: '1', stage: FulfilmentStage.audited),
    ]);
    await openQueue(tester, 'Audited');
    await openShipment(tester, 'YK-1');

    expect(find.text('Waiting for the rider'), findsOneWidget);
    expect(find.text('Mark audited'), findsNothing);
  });

  testWidgets('the stock tab lists products and filters by search',
      (tester) async {
    await signIn(tester);

    await openTab(tester, Icons.inventory_2_outlined);

    expect(find.text('Widget'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'nothing');
    await tester.pumpAndSettle();

    expect(find.text('Nothing matches'), findsOneWidget);
  });

  testWidgets('a stock count runs from start to submit', (tester) async {
    await signIn(tester);

    await openTab(tester, Icons.checklist_outlined);

    expect(find.text('No count open'), findsOneWidget);

    await tester.tap(find.textContaining('Count everything'));
    await tester.pumpAndSettle();

    expect(find.text('Not counted yet'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    expect(find.text('Counted 1'), findsOneWidget);

    await tester.tap(find.textContaining('Submit'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Submit').last);
    await tester.pumpAndSettle();

    expect(find.text('No count open'), findsOneWidget);
  });

  testWidgets('the profile shows the role and what it may do', (tester) async {
    await signIn(tester);

    await openTab(tester, Icons.person_outline);

    expect(find.text('Sokha Chan'), findsOneWidget);
    expect(find.text('Mark shipments audited'), findsOneWidget);
    expect(find.text('To pack'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('signing out returns to the sign-in screen', (tester) async {
    await signIn(tester);

    await openTab(tester, Icons.person_outline);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
  });
}
