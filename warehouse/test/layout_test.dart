import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse/app.dart';
import 'package:warehouse/models/fulfilment_stage.dart';
import 'package:warehouse/models/hrm.dart';
import 'package:warehouse/screens/hrm_screen.dart';
import 'package:warehouse/services/camera.dart';
import 'package:warehouse/services/location.dart';

import 'fixtures.dart';
import 'hrm_fixtures.dart';

/// Layout guards at the size the app is actually used at.
///
/// The tall surface the other widget tests use hides overflow, and this app
/// found two real ones that way: the queue tabs at phone width, and a fixed
/// height under the empty-count pane. Flutter throws on an overflow during a
/// test, so pumping each screen at a small real phone size *is* the assertion.
/// Portrait only: the app locks itself to it, so landscape is not a shape it
/// has to hold.
const _smallPhone = Size(360, 640);

Future<void> pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  LocationService.current = () async => null;
  Camera.takePhoto = () async => null;

  final start = DateTime.now().subtract(const Duration(hours: 9));
  await tester.pumpWidget(
    WarehouseApp(
      repository: repositoryWith(),
      auth: FakeAuthApi(),
      hrm: FakeHrmApi(
        shifts: [
          buildShift(
              clockIn: start,
              clockOut: start.add(const Duration(hours: 8)),
              note: 'A note long enough to wrap on a narrow phone screen'),
          buildShift(id: 'local:2', clockIn: DateTime.now()),
        ],
        leaves: [buildLeave(reason: 'A reason long enough to wrap twice over')],
        holidays: [
          Holiday(
              id: '1',
              name: 'Pchum Ben',
              start: DateTime.now(),
              end: DateTime.now().add(const Duration(days: 2)),
              note: 'Three days off for everyone in the building'),
        ],
        payrolls: [
          const PayrollSummary(
              id: '1', month: '2026-08', netPay: 1650000, basicSalary: 1500000),
        ],
        payslips: {
          '1': const Payslip(
            id: '1',
            monthLabel: 'August 2026',
            netPay: 1650000,
            lines: [
              PayLine(label: 'Basic salary', amount: 1500000, kind: 'base'),
              PayLine(
                  label: 'A very long allowance name that wraps',
                  amount: 150000),
            ],
            presentDays: 24,
            absentDays: 2,
            scheduledDays: 26,
            lateMinutes: 90,
            clockedHours: 190.5,
            shift: '08:00 – 17:00',
            absentDates: ['2026-08-04', '2026-08-19'],
          ),
        },
      ),
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

  testWidgets('stock, HRM and profile lay out on a small phone',
      (tester) async {
    await pumpAt(tester, _smallPhone);

    await openTab(tester, Icons.inventory_2_outlined);
    await openTab(tester, Icons.badge_outlined);
    await openTab(tester, Icons.person_outline);
  });

  testWidgets('an open count lays out on a small phone', (tester) async {
    await pumpAt(tester, _smallPhone);

    await openTab(tester, Icons.inventory_2_outlined);
    await tester.tap(find.byTooltip('Stock count'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Count everything'));
    await tester.pumpAndSettle();

    expect(find.text('Not counted yet'), findsWidgets);
  });

  testWidgets('every HRM screen lays out on a small phone', (tester) async {
    await pumpAt(tester, _smallPhone);
    await openTab(tester, Icons.badge_outlined);

    // The punch dialog, then each door and the page behind it.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Clock out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    for (final door in [
      'Attendance',
      'Leave',
      'Holidays',
      'Leave approvals',
      'Payroll'
    ]) {
      // The lower doors sit below the fold on a small phone.
      await tester.scrollUntilVisible(
        find.text(door),
        120,
        scrollable: find
            .descendant(
                of: find.byType(HrmScreen), matching: find.byType(Scrollable))
            .first,
      );
      await tester.tap(find.text(door));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).last, const Offset(0, -600));
      await tester.pumpAndSettle();
      if (door == 'Leave') {
        await tester.tap(find.text('Request leave'));
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
      if (door == 'Payroll') {
        await tester.tap(find.text('August 2026'));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView).last, const Offset(0, -900));
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });
}
