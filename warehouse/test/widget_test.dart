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
    WarehouseApp(repository: repositoryWith(orders: orders)),
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

/// Pumps the app with fixtures and signs in, which every screen sits behind.
Future<void> signIn(WidgetTester tester, {List<Order>? orders}) async {
  await pumpApp(tester, orders: orders);

  await tester.enterText(find.byType(TextField).at(1), '1234');
  await tester.tap(find.text('Sign in'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the app opens on the sign-in screen', (tester) async {
    await pumpApp(tester);

    expect(find.text('Warehouse'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('a short PIN is refused', (tester) async {
    await pumpApp(tester);

    await tester.enterText(find.byType(TextField).at(1), '12');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Your PIN is 4 digits.'), findsOneWidget);
  });

  testWidgets('signing in lands on the three order queues', (tester) async {
    await signIn(tester);

    expect(find.text('Prepare'), findsOneWidget);
    expect(find.text('Check'), findsOneWidget);
    expect(find.text('Driver'), findsOneWidget);
  });

  testWidgets('an empty queue says so in its own words', (tester) async {
    await signIn(tester, orders: [
      buildOrder(id: '1', stage: FulfilmentStage.checked),
    ]);

    expect(find.text('Nothing to prepare'), findsOneWidget);
  });

  testWidgets('opening an order shows its lines and the scan box',
      (tester) async {
    await signIn(tester, orders: [
      buildOrder(id: '1', lines: [buildLine(quantity: 2)]),
    ]);

    await tester.tap(find.text('YK-1'));
    await tester.pumpAndSettle();

    expect(find.text('Pick these'), findsOneWidget);
    expect(find.text('Scan or type a barcode'), findsOneWidget);
    expect(find.text('0 / 2'), findsWidgets);
  });

  testWidgets('scanning a barcode picks one unit', (tester) async {
    await signIn(tester, orders: [
      buildOrder(id: '1', lines: [buildLine(quantity: 2)]),
    ]);

    await tester.tap(find.text('YK-1'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'BC-1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('1 / 2'), findsWidgets);
  });

  testWidgets('scanning a code from another order is reported', (tester) async {
    await signIn(tester, orders: [
      buildOrder(id: '1', lines: [buildLine(quantity: 1)]),
    ]);

    await tester.tap(find.text('YK-1'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'BC-WRONG');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.textContaining('is not on this order'), findsOneWidget);
  });

  testWidgets('"take all" fills a line and unlocks the stage button',
      (tester) async {
    await signIn(tester, orders: [
      buildOrder(id: '1', lines: [buildLine(quantity: 3)]),
    ]);

    await tester.tap(find.text('YK-1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Take all 3'));
    await tester.pumpAndSettle();

    expect(find.text('3 / 3'), findsWidgets);

    await tester.tap(find.text('Mark prepared'));
    await tester.pumpAndSettle();

    expect(find.textContaining('prepared'), findsWidgets);
  });

  testWidgets('a short pick asks for a note before it can move on',
      (tester) async {
    await signIn(tester, orders: [
      buildOrder(id: '1', lines: [buildLine(quantity: 3, picked: 1)]),
    ]);

    await tester.tap(find.text('YK-1'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Short by 2'), findsOneWidget);

    await tester.tap(find.text('Mark prepared'));
    await tester.pumpAndSettle();

    // The dialog asking why, rather than a silent refusal.
    expect(find.text('Add a note'), findsWidgets);
  });

  testWidgets('a checked order tells staff to wait for the driver',
      (tester) async {
    await signIn(tester, orders: [
      buildOrder(
        id: '1',
        stage: FulfilmentStage.checked,
        lines: [buildLine(quantity: 1, picked: 1)],
      ),
    ]);

    await tester.tap(find.text('Driver'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('YK-1'));
    await tester.pumpAndSettle();

    expect(find.text('Packed and waiting'), findsOneWidget);
    expect(find.text('Mark prepared'), findsNothing);
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
    expect(find.text('Sign off checks'), findsOneWidget);
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
