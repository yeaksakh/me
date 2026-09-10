import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse/models/hrm.dart';
import 'package:warehouse/state/hrm_controller.dart';

import 'hrm_fixtures.dart';

HrmController controllerOver(FakeHrmApi api, {bool signedOut = false}) =>
    HrmController(api, userId: () => signedOut ? null : '42');

void main() {
  group('The clock', () {
    test('starts unknown, then knows nobody is clocked in', () async {
      final hrm = controllerOver(FakeHrmApi());
      expect(hrm.shiftLoaded, isFalse);

      await hrm.loadShift();

      expect(hrm.shiftLoaded, isTrue);
      expect(hrm.isClockedIn, isFalse);
    });

    test('clocking in opens a shift, with the note and the position', () async {
      final api = FakeHrmApi();
      final hrm = controllerOver(api);
      await hrm.loadShift();

      final action = await hrm.clock(
        note: 'floor',
        position: (latitude: 11.5, longitude: 104.9),
      );

      expect(action, 'in');
      expect(hrm.isClockedIn, isTrue);
      expect(hrm.openShift!.note, 'floor');
      expect(api.punches.single['lat'], 11.5);
    });

    test('with a shift open, the same button clocks out', () async {
      final api = FakeHrmApi(shifts: [buildShift(clockIn: DateTime.now())]);
      final hrm = controllerOver(api);
      await hrm.loadShift();
      expect(hrm.isClockedIn, isTrue);

      final action = await hrm.clock();

      expect(action, 'out');
      expect(hrm.isClockedIn, isFalse);
      expect(api.punches.single['action'], 'out');
    });

    test("a refusal is the server's sentence, and the state is re-read", () async {
      final api = FakeHrmApi();
      final hrm = controllerOver(api);
      await hrm.loadShift();
      // The kiosk clocked them in meanwhile.
      api.shifts.add(buildShift(clockIn: DateTime.now()));

      final action = await hrm.clock();

      expect(action, isNull);
      expect(hrm.error, 'This user is already clocked in.');
      expect(hrm.isClockedIn, isTrue);
    });

    test('nothing is asked for while nobody is signed in', () async {
      final api = FakeHrmApi();
      final hrm = controllerOver(api, signedOut: true);

      await hrm.loadShift();

      expect(hrm.shiftLoaded, isFalse);
    });

    test('an expired session signs out', () async {
      var signedOut = false;
      final hrm = HrmController(
        FakeHrmApi()..expired = true,
        userId: () => '42',
        onUnauthorized: () => signedOut = true,
      );

      await hrm.loadShift();

      expect(signedOut, isTrue);
      expect(hrm.error, contains('expired'));
    });
  });

  group('Leave', () {
    test('a request needs a reason and dates in order', () async {
      final hrm = controllerOver(FakeHrmApi());
      const sick = LeaveType(id: 'sick', label: 'Sick');

      expect(
        await hrm.requestLeave(
            type: sick, start: DateTime(2026, 9, 10), end: DateTime(2026, 9, 10), reason: ' '),
        isFalse,
      );
      expect(hrm.error, contains('why'));

      expect(
        await hrm.requestLeave(
            type: sick, start: DateTime(2026, 9, 10), end: DateTime(2026, 9, 8), reason: 'x'),
        isFalse,
      );
      expect(hrm.error, contains('before'));
    });

    test('a request lands as pending in the list', () async {
      final hrm = controllerOver(FakeHrmApi());

      final done = await hrm.requestLeave(
        type: const LeaveType(id: 'sick', label: 'Sick'),
        start: DateTime(2026, 9, 10),
        end: DateTime(2026, 9, 11),
        reason: 'fever',
      );

      expect(done, isTrue);
      expect(hrm.leaves.single.status, LeaveStatus.pending);
      expect(hrm.leaves.single.totalDays, 2);
    });

    test('a decision changes the status', () async {
      final api = FakeHrmApi(leaves: [buildLeave(id: 'l1')]);
      final hrm = controllerOver(api);
      await hrm.loadLeaves();

      expect(await hrm.setLeaveStatus('l1', LeaveStatus.approved), isTrue);
      expect(hrm.leaves.single.status, LeaveStatus.approved);
      expect(api.statusChanges, [LeaveStatus.approved]);
    });
  });
}
