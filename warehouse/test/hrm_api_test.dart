import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warehouse/data/api_client.dart';
import 'package:warehouse/data/hrm_api.dart';
import 'package:warehouse/models/hrm.dart';

http.Response json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

HrmApi apiAnswering(http.Response Function(http.Request request) answer) =>
    HrmApi(ApiClient(
      baseUrl: () => 'https://yeaksa.com',
      token: () => 'tok-123',
      httpClient: MockClient((request) async => answer(request)),
    ));

/// One shift, shaped as `GET /api/attendance` sends it.
Map<String, dynamic> shiftJson({bool open = true}) => {
      'source': 'local',
      'id': 9114,
      'user_id': 42,
      'user_name': 'Sok Dara',
      'clock_in_time': '2026-09-10T01:12:03Z',
      'clock_out_time': open ? null : '2026-09-10T10:41:55Z',
      'ip_address': '203.0.113.9',
      'clock_in_note': 'shop floor',
      'clock_out_note': null,
      'clock_in_lat': 11.5564,
      'clock_in_lng': 104.9282,
      'clock_out_lat': null,
      'clock_out_lng': null,
      'clock_in_photo': 'https://yeaksa.com/uploads/companies/3/attendance/x.webp',
      'clock_out_photo': '',
      'clock_in_location': '11.5564, 104.9282',
      'clock_out_location': null,
    };

void main() {
  test('the open shift is asked for by user, open=1, with the token', () async {
    late http.Request sent;
    final api = apiAnswering((request) {
      sent = request;
      return json({'success': true, 'data': [shiftJson()]});
    });

    final shift = await api.openShift('42');

    expect(sent.url.path, '/api/attendance');
    expect(sent.url.queryParameters['user_id'], '42');
    expect(sent.url.queryParameters['open'], '1');
    expect(sent.headers['Authorization'], 'Bearer tok-123');
    expect(shift!.isOpen, isTrue);
    expect(shift.clockIn.toUtc(), DateTime.utc(2026, 9, 10, 1, 12, 3));
    expect(shift.note, 'shop floor');
    expect(shift.inLatitude, 11.5564);
    expect(shift.inPhotoUrl, contains('attendance/x.webp'));
    expect(shift.outPhotoUrl, isNull);
  });

  test('no open shift reads as null, not as an error', () async {
    final api = apiAnswering((_) => json({'success': true, 'data': []}));
    expect(await api.openShift('42'), isNull);
  });

  test('history sends the window as calendar days', () async {
    late http.Request sent;
    final api = apiAnswering((request) {
      sent = request;
      return json({'success': true, 'data': [shiftJson(open: false)]});
    });

    final shifts = await api.attendance('42',
        from: DateTime(2026, 9, 1), to: DateTime(2026, 9, 10));

    expect(sent.url.queryParameters['from'], '2026-09-01');
    expect(sent.url.queryParameters['to'], '2026-09-10');
    expect(shifts.single.isOpen, isFalse);
    expect(shifts.single.worked, const Duration(hours: 9, minutes: 29, seconds: 52));
  });

  test('a clock-in posts action, note and position as JSON', () async {
    late http.Request sent;
    final api = apiAnswering((request) {
      sent = request;
      return json({'success': true, 'data': {'id': 1, 'clock_in_time': 'x'}});
    });

    await api.clock('in', note: ' floor ', latitude: 11.5, longitude: 104.9);

    expect(sent.method, 'POST');
    expect(sent.url.path, '/api/attendance/clock');
    expect(sent.headers['Content-Type'], startsWith('application/json'));
    expect(jsonDecode(sent.body),
        {'action': 'in', 'note': 'floor', 'lat': '11.5', 'lng': '104.9'});
  });

  test('a clock-out with a photo goes up as multipart', () async {
    late http.Request sent;
    final api = apiAnswering((request) {
      sent = request;
      return json({'success': true, 'data': {'id': 1, 'clock_out_time': 'x'}});
    });

    // A file the picker would have written.
    final dir = await Directory.systemTemp.createTemp('wh-test');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/selfie.jpg')..writeAsBytesSync([1, 2, 3]);
    await api.clock('out', photoPath: file.path);

    expect(sent.headers['Content-Type'], startsWith('multipart/form-data'));
    final body = utf8.decode(sent.bodyBytes, allowMalformed: true);
    expect(body, contains('name="action"'));
    expect(body, contains('out'));
    expect(body, contains('name="photo"; filename="selfie.jpg"'));
  });

  test("a refusal carries the server's words and code", () async {
    final api = apiAnswering((_) => json({
          'success': false,
          'error': 'already_in',
          'message': 'This user is already clocked in.',
        }, 400));

    await expectLater(
      api.clock('in'),
      throwsA(isA<ApiException>()
          .having((e) => e.message, 'message', 'This user is already clocked in.')
          .having((e) => e.code, 'code', 'already_in')),
    );
  });

  test('leave types keep the key the server wants back', () async {
    final api = apiAnswering((_) => json({
          'success': true,
          'data': [
            {'id': 'annual', 'key': 'annual', 'leave_type': 'ច្បាប់ប្រចាំឆ្នាំ (Annual leave)'},
          ],
        }));

    final types = await api.leaveTypes();

    expect(types.single.id, 'annual');
    expect(types.single.label, contains('Annual leave'));
  });

  test('a leave request posts the kind, the days and the reason', () async {
    late http.Request sent;
    final api = apiAnswering((request) {
      sent = request;
      return json({
        'success': true,
        'data': {
          'id': 749, 'ref_no': '#749', 'user_id': 42, 'leave_type': 'sick',
          'leave_type_label': 'ច្បាប់ឈឺ (Sick leave)', 'start_date': '2026-09-10',
          'end_date': '2026-09-12', 'total_days': 3, 'is_half_day': false,
          'status': 'pending',
        },
      });
    });

    final leave = await api.requestLeave(
      type: 'sick',
      start: DateTime(2026, 9, 10),
      end: DateTime(2026, 9, 12),
      reason: 'fever',
    );

    expect(sent.url.path, '/api/leaves/create');
    expect(jsonDecode(sent.body), {
      'leave_type': 'sick',
      'start_date': '2026-09-10',
      'end_date': '2026-09-12',
      'reason': 'fever',
    });
    expect(leave.status, LeaveStatus.pending);
    expect(leave.totalDays, 3);
    expect(leave.daysLabel, '3 days');
  });

  test('a half day is one date and says so', () async {
    late http.Request sent;
    final api = apiAnswering((request) {
      sent = request;
      return json({
        'success': true,
        'data': {'id': 1, 'start_date': '2026-09-10', 'end_date': '2026-09-10',
                 'total_days': 0.5, 'is_half_day': true, 'status': 'pending'},
      });
    });

    final leave = await api.requestLeave(
      type: 'sick',
      start: DateTime(2026, 9, 10),
      end: DateTime(2026, 9, 14),
      reason: 'doctor',
      halfDay: true,
    );

    final body = jsonDecode(sent.body) as Map<String, dynamic>;
    expect(body['end_date'], '2026-09-10');
    expect(body['is_half_day'], isTrue);
    expect(leave.daysLabel, 'Half day');
  });

  test('a decision posts the status', () async {
    late http.Request sent;
    final api = apiAnswering((request) {
      sent = request;
      return json({'success': true, 'data': {'id': 748, 'status': 'approved'}});
    });

    await api.setLeaveStatus('748', LeaveStatus.approved);

    expect(sent.url.path, '/api/leaves/748/status');
    expect(jsonDecode(sent.body), {'status': 'approved'});
  });

  test('payrolls come out of the nested envelope, and a payslip parses', () async {
    final api = apiAnswering((request) {
      if (request.url.path == '/api/payrolls/mine') {
        return json({
          'success': true,
          'data': {
            'payrolls': [
              {'id': 331, 'month': '2026-08', 'net_pay': 412.75,
               'basic_salary': 450.0, 'payment_status': 'final',
               'paid_on': '2026-09-05'},
            ],
            'pay_components': [],
          },
        });
      }
      return json({
        'success': true,
        'data': {
          'id': 331, 'month_label': 'August 2026', 'net_pay': 412.75,
          'basic_salary': {'amount': 450.0, 'details': {}},
          'total_earnings': 470.0, 'total_deductions': 57.25,
          'lines': [
            {'label': 'Basic salary', 'amount': 450.0, 'kind': 'base', 'when': ''},
            {'label': 'Late', 'amount': 7.25, 'kind': 'minus', 'when': '3 days'},
          ],
          'work': {'present_days': 24, 'absent_days': 1, 'scheduled_days': 25,
                   'late_minutes': 42, 'clocked_seconds': 628195.5,
                   'shift': '08:00 – 17:00', 'absent_dates': ['2026-08-14']},
          'leaves': [],
          'payment': {'paid_on': '2026-09-05', 'paid_by': 'Owner'},
          'employee': {'full_name': 'Sok Dara'},
        },
      });
    });

    final list = await api.payrolls();
    expect(list.single.month, '2026-08');
    expect(list.single.netPay, 412.75);
    expect(list.single.paidOn, DateTime(2026, 9, 5));

    final slip = await api.payslip('331');
    expect(slip.monthLabel, 'August 2026');
    expect(slip.basicSalary, 450.0);
    expect(slip.lines.last.isDeduction, isTrue);
    expect(slip.presentDays, 24);
    expect(slip.clockedHours, closeTo(174.5, 0.1));
    expect(slip.absentDates, ['2026-08-14']);
    expect(slip.isPaid, isTrue);
    expect(slip.paidBy, 'Owner');
  });

  test('holidays parse with their span', () async {
    final api = apiAnswering((_) => json({
          'success': true,
          'data': [
            {'id': 21, 'name': 'Pchum Ben', 'holiday_type': 'public',
             'start_date': '2026-09-21', 'end_date': '2026-09-23',
             'is_recurring': false, 'note': null},
          ],
        }));

    final holidays = await api.holidays(from: DateTime(2026), to: DateTime(2026, 12, 31));

    expect(holidays.single.name, 'Pchum Ben');
    expect(holidays.single.days, 3);
  });
}
