import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse/app.dart';
import 'package:warehouse/models/fulfilment_stage.dart';
import 'package:warehouse/models/hrm.dart';
import 'package:warehouse/models/order.dart';
import 'package:warehouse/services/camera.dart';
import 'package:warehouse/services/location.dart';

import 'fixtures.dart';
import 'hrm_fixtures.dart';

/// Pumps the app on a phone-width but very tall surface.
///
/// Width stays phone-sized so the layout under test is the real one; the height
/// is stretched so a screen's whole ListView is built at once and a finder does
/// not miss a widget merely because it is below the fold.
Future<void> pumpApp(WidgetTester tester,
    {List<Order>? orders, FakeHrmApi? hrm}) async {
  tester.view.physicalSize = const Size(420, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  // No location service and no camera under flutter_test.
  LocationService.current = () async => null;
  Camera.takePhoto = () async => null;

  await tester.pumpWidget(
    WarehouseApp(
      repository: repositoryWith(),
      auth: FakeAuthApi(),
      shipments: FakeShipmentsApi(orders: orders),
      hrm: hrm ?? FakeHrmApi(),
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
Future<void> signIn(WidgetTester tester,
    {List<Order>? orders, FakeHrmApi? hrm}) async {
  await pumpApp(tester, orders: orders, hrm: hrm);
  await submitSignIn(tester);
}

/// Signs in and opens the HRM tab.
Future<void> openHrm(WidgetTester tester, {FakeHrmApi? hrm}) async {
  await signIn(tester, hrm: hrm);
  await openTab(tester, Icons.badge_outlined);
}

void main() {
  testWidgets('the app opens on the sign-in screen', (tester) async {
    await pumpApp(tester);

    expect(find.text('WareHouseMgt'), findsOneWidget);
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

  testWidgets('an accepted shipment says who has it and where each item sits',
      (tester) async {
    await signIn(tester, orders: [
      buildOrder(id: '1', preparedById: supervisor.id, lines: [
        buildLine(id: 'a', rack: 'K', row: 'K6/0', position: 'K6'),
        buildLine(id: 'b', name: 'Loose thing'),
      ]),
    ]);
    await openShipment(tester, 'YK-1');

    expect(find.text('Accepted by Sokha Chan (you)'), findsOneWidget);
    expect(find.text('Rack K  ·  Row K6/0  ·  Position K6'), findsOneWidget);
    expect(find.text('No rack location set'), findsOneWidget);
    // The keyboard must not cover the items: the scan box waits to be tapped.
    expect(
      tester.widget<TextField>(find.byType(TextField).first).autofocus,
      isFalse,
    );
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

  testWidgets('the record shows when it was accepted, packed and audited, '
      'and when each photo went up', (tester) async {
    await signIn(tester, orders: [
      buildOrder(
        id: '1',
        stage: FulfilmentStage.audited,
        preparedById: supervisor.id,
        acceptedAt: DateTime(2026, 9, 10, 9, 15),
        packedAt: DateTime(2026, 9, 10, 9, 40),
        packedByName: 'Sokha Chan',
        auditedAt: DateTime(2026, 9, 10, 10, 5),
        auditedByName: 'Chan Vy',
        photos: [
          OrderPhoto(
            url: 'http://example.test/p.webp',
            stage: FulfilmentStage.audited,
            takenAt: DateTime(2026, 9, 10, 10, 4),
          ),
        ],
      ),
    ]);
    await openQueue(tester, 'Audited');
    await openShipment(tester, 'YK-1');

    expect(find.text('Accepted by Sokha Chan (you) · Sep 10, 9:15 AM'),
        findsOneWidget);
    expect(find.text('Packed by Sokha Chan · Sep 10, 9:40 AM'), findsOneWidget);
    expect(find.text('Audited by Chan Vy · Sep 10, 10:05 AM'), findsOneWidget);
    expect(find.text('Sep 10, 10:04 AM'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Wrap),
        matching: find.text('Audited'),
      ),
      findsOneWidget,
    );
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

    await openTab(tester, Icons.inventory_2_outlined);
    await tester.tap(find.byTooltip('Stock count'));
    await tester.pumpAndSettle();

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

  group('HRM', () {
    testWidgets('the tab offers Clock in, and a punch flips it to Clock out',
        (tester) async {
      final hrm = FakeHrmApi();
      await openHrm(tester, hrm: hrm);

      expect(find.text('Not clocked in'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Clock in'));
      await tester.pumpAndSettle();

      expect(find.text('Start your shift now?'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'front gate');
      await tester.tap(find.widgetWithText(FilledButton, 'Clock in'));
      await tester.pumpAndSettle();

      expect(find.text('Clocked in'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Clock out'), findsOneWidget);
      expect(find.textContaining('Clocked in at'), findsOneWidget);
      expect(hrm.punches.single['action'], 'in');
      expect(hrm.punches.single['note'], 'front gate');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Clock out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Clock out'));
      await tester.pumpAndSettle();

      expect(find.text('Not clocked in'), findsOneWidget);
      expect(hrm.punches.last['action'], 'out');
    });

    testWidgets("a shift opened elsewhere shows as open, with since when",
        (tester) async {
      await openHrm(tester, hrm: FakeHrmApi(shifts: [
        buildShift(clockIn: DateTime.now().subtract(const Duration(hours: 2))),
      ]));

      expect(find.text('Clocked in'), findsOneWidget);
      expect(find.textContaining('Since'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Clock out'), findsOneWidget);
    });

    testWidgets("the server's refusal is shown as it comes", (tester) async {
      final hrm = FakeHrmApi();
      await openHrm(tester, hrm: hrm);
      // The kiosk clocked them in after the screen loaded.
      hrm.shifts.add(buildShift(clockIn: DateTime.now()));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Clock in'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Clock in'));
      await tester.pumpAndSettle();

      expect(find.text('This user is already clocked in.'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Clock out'), findsOneWidget);
    });

    testWidgets('attendance lists the shifts with their hours', (tester) async {
      final start = DateTime.now().subtract(const Duration(hours: 9));
      await openHrm(tester, hrm: FakeHrmApi(shifts: [
        buildShift(
          clockIn: start,
          clockOut: start.add(const Duration(hours: 8, minutes: 30)),
          note: 'yard',
        ),
      ]));

      await tester.tap(find.text('Attendance'));
      await tester.pumpAndSettle();

      expect(find.text('8h 30m'), findsWidgets);
      expect(find.text('yard'), findsOneWidget);
      expect(find.text('Days worked'), findsOneWidget);
    });

    testWidgets('leave can be requested and lands as pending', (tester) async {
      await openHrm(tester);

      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      expect(find.text('No leave requests'), findsOneWidget);

      await tester.tap(find.text('Request leave'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<LeaveType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ច្បាប់ឈឺ (Sick leave)').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Fever');
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();

      expect(find.text('Leave requested — waiting for approval.'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Fever'), findsOneWidget);
    });

    testWidgets('a request without a kind of leave is stopped', (tester) async {
      await openHrm(tester);
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Request leave'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();

      expect(find.text('Choose the kind of leave.'), findsOneWidget);
    });

    testWidgets('a supervisor approves a request', (tester) async {
      final hrm = FakeHrmApi(leaves: [
        buildLeave(id: 'l1', userName: 'Sok Dara', reason: 'Wedding'),
      ]);
      await openHrm(tester, hrm: hrm);

      await tester.tap(find.text('Leave approvals'));
      await tester.pumpAndSettle();
      expect(find.text('Sok Dara'), findsOneWidget);

      await tester.tap(find.text('Wedding'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      expect(find.text('Sok Dara: Approved.'), findsOneWidget);
      expect(hrm.statusChanges, [LeaveStatus.approved]);
    });

    testWidgets('holidays list the year, coming up first', (tester) async {
      final soon = DateTime.now().add(const Duration(days: 20));
      await openHrm(tester, hrm: FakeHrmApi(holidays: [
        Holiday(id: '1', name: 'Pchum Ben', start: soon,
            end: soon.add(const Duration(days: 2))),
        Holiday(id: '2', name: 'Khmer New Year', start: DateTime(2026, 4, 14),
            end: DateTime(2026, 4, 16)),
      ]));

      await tester.tap(find.text('Holidays'));
      await tester.pumpAndSettle();

      expect(find.text('Coming up'), findsOneWidget);
      expect(find.text('Pchum Ben'), findsOneWidget);
      expect(find.text('Already passed'), findsOneWidget);
      expect(find.text('Khmer New Year'), findsOneWidget);
    });

    testWidgets('payroll lists the months and opens a payslip', (tester) async {
      await openHrm(tester, hrm: FakeHrmApi(
        payrolls: [
          const PayrollSummary(id: '331', month: '2026-08', netPay: 412.75,
              basicSalary: 450, paidOn: null),
        ],
        payslips: {
          '331': const Payslip(
            id: '331', monthLabel: 'August 2026', netPay: 412.75,
            basicSalary: 450, totalEarnings: 470, totalDeductions: 57.25,
            lines: [
              PayLine(label: 'Basic salary', amount: 450, kind: 'base'),
              PayLine(label: 'Late', amount: 7.25, kind: 'minus', when: '3 days'),
            ],
            presentDays: 24, absentDays: 1, scheduledDays: 25, lateMinutes: 42,
          ),
        },
      ));

      await tester.tap(find.text('Payroll'));
      await tester.pumpAndSettle();
      expect(find.text('August 2026'), findsOneWidget);
      expect(find.text(r'$412.75'), findsWidgets);

      await tester.tap(find.text('August 2026'));
      await tester.pumpAndSettle();

      expect(find.text('Net pay'), findsWidgets);
      expect(find.text('Late'), findsWidgets);
      expect(find.text('24 of 25'), findsOneWidget);
      expect(find.text('Not paid yet'), findsOneWidget);
    });
  });
}
