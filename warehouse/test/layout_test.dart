import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse/app.dart';
import 'package:warehouse/models/fulfilment_stage.dart';

import 'fixtures.dart';

/// Layout guards at the size the app is actually used at.
///
/// The tall surface the other widget tests use hides overflow, and this app
/// found two real ones that way: the queue tabs at phone width, and a fixed
/// height under the empty-count pane. Flutter throws on an overflow during a
/// test, so pumping each screen at a small real phone size *is* the assertion.
const _smallPhone = Size(360, 640);

Future<void> pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    WarehouseApp(
      repository: repositoryWith(),
      auth: FakeAuthApi(),
      shipments: FakeShipmentsApi(orders: [
        // Accepted, part-packed, with a bundle item and a long name: the
        // busiest detail screen there is.
        buildOrder(
          id: '1',
          preparedById: supervisor.id,
          note: 'Fragile, keep upright',
          lines: [
            buildLine(id: 'a', quantity: 3, packed: true),
            buildLine(
              id: 'b',
              parentId: 'a',
              name: 'A product with a name long enough to wrap twice',
            ),
          ],
        ),
        buildOrder(id: '4', preparedById: 'x9', preparedByName: 'Someone Else'),
        buildOrder(id: '2', stage: FulfilmentStage.packed),
        buildOrder(id: '3', stage: FulfilmentStage.audited),
      ]),
    ),
  );
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField).at(0), 'sokha');
  await tester.enterText(find.byType(TextField).at(1), 'secret');
  // In landscape the sign-in screen legitimately scrolls, so bring the button
  // into view rather than tapping at a point that is off the viewport.
  await tester.ensureVisible(find.text('Sign in'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Sign in'));
  await tester.pumpAndSettle();
}

Future<void> openTab(WidgetTester tester, IconData icon) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.byIcon(icon),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openQueue(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(TabBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the shipment tabs fit a small phone', (tester) async {
    await pumpAt(tester, _smallPhone);
    expect(
      find.descendant(of: find.byType(TabBar), matching: find.text('Ordered')),
      findsOneWidget,
    );
  });

  testWidgets('each tab lays out on a small phone', (tester) async {
    await pumpAt(tester, _smallPhone);

    for (final label in ['Packed', 'Audited', 'Ordered']) {
      await openQueue(tester, label);
    }
  });

  testWidgets('a shipment being packed lays out on a small phone',
      (tester) async {
    await pumpAt(tester, _smallPhone);

    await tester.tap(find.text('YK-1'));
    await tester.pumpAndSettle();

    // Scroll the whole page, so anything below the fold is laid out too.
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
  });

  testWidgets("someone else's shipment lays out on a small phone",
      (tester) async {
    await pumpAt(tester, _smallPhone);

    await tester.tap(find.text('YK-4'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
  });

  testWidgets('stock, count and profile lay out on a small phone',
      (tester) async {
    await pumpAt(tester, _smallPhone);

    await openTab(tester, Icons.inventory_2_outlined);
    await openTab(tester, Icons.checklist_outlined);
    await openTab(tester, Icons.person_outline);
  });

  testWidgets('an open count lays out on a small phone', (tester) async {
    await pumpAt(tester, _smallPhone);

    await openTab(tester, Icons.checklist_outlined);
    await tester.tap(find.textContaining('Count everything'));
    await tester.pumpAndSettle();

    expect(find.text('Not counted yet'), findsWidgets);
  });

  testWidgets('a landscape handset still lays out', (tester) async {
    await pumpAt(tester, const Size(740, 360));
    expect(
      find.descendant(of: find.byType(TabBar), matching: find.text('Ordered')),
      findsOneWidget,
    );
  });
}
