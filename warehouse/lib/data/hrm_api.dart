import '../models/hrm.dart';
import 'api_client.dart';

export 'api_client.dart' show ApiException;

/// Attendance, leave, holidays and pay: the HRM half of the staff API, the same
/// endpoints YeaksaMax uses. Every call carries the person's own token, so the
/// server records them as the one clocking in or asking for leave.
class HrmApi {
  HrmApi(this._client);

  final ApiClient _client;

  // ---------------------------------------------------------------------------
  // attendance
  // ---------------------------------------------------------------------------

  /// The shift still open for [userId], whatever day it began, or null.
  Future<AttendanceEntry?> openShift(String userId) async {
    final body = await _client.get('/api/attendance',
        query: {'user_id': userId, 'open': '1', 'limit': '1'});
    final rows = _rows(body);
    return rows.isEmpty ? null : AttendanceEntry.fromApi(rows.first);
  }

  /// Shifts for [userId] between two calendar days, newest first.
  Future<List<AttendanceEntry>> attendance(
    String userId, {
    required DateTime from,
    required DateTime to,
    int limit = 200,
  }) async {
    final body = await _client.get('/api/attendance', query: {
      'user_id': userId,
      'from': _ymd(from),
      'to': _ymd(to),
      'limit': '$limit',
    });
    return _rows(body).map(AttendanceEntry.fromApi).toList();
  }

  /// Clocks the signed-in person in or out. The server stamps the time and
  /// records the IP; the position and photo travel when the phone has them.
  Future<void> clock(
    String action, {
    String? note,
    double? latitude,
    double? longitude,
    String? photoPath,
  }) async {
    final fields = <String, String>{
      'action': action,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      if (latitude != null) 'lat': '$latitude',
      if (longitude != null) 'lng': '$longitude',
    };
    if (photoPath != null) {
      await _client.postMultipart('/api/attendance/clock', fields,
          fileField: 'photo', filePath: photoPath);
    } else {
      await _client.post('/api/attendance/clock', fields);
    }
  }

  // ---------------------------------------------------------------------------
  // leave
  // ---------------------------------------------------------------------------

  /// Leave requests the signed-in person may see: their own, or everyone's
  /// for someone who approves them.
  Future<List<LeaveRequest>> leaves(
      {LeaveStatus? status, int limit = 200}) async {
    final body = await _client.get('/api/leaves', query: {
      if (status != null) 'status': status.apiValue,
      'limit': '$limit',
    });
    return _rows(body).map(LeaveRequest.fromApi).toList();
  }

  Future<List<LeaveType>> leaveTypes() async {
    final body = await _client.get('/api/leave-types');
    return _rows(body)
        .map(LeaveType.fromApi)
        .where((type) => type.id.isNotEmpty)
        .toList();
  }

  Future<LeaveRequest> requestLeave({
    required String type,
    required DateTime start,
    required DateTime end,
    required String reason,
    bool halfDay = false,
  }) async {
    final body = await _client.post('/api/leaves/create', {
      'leave_type': type,
      'start_date': _ymd(start),
      'end_date': _ymd(halfDay ? start : end),
      'reason': reason.trim(),
      if (halfDay) 'is_half_day': true,
    });
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException('The server sent something the app could not read.');
    }
    return LeaveRequest.fromApi(data);
  }

  /// Approve, reject or cancel a request. A manager's call on the server.
  Future<void> setLeaveStatus(String id, LeaveStatus status) =>
      _client.post('/api/leaves/$id/status', {'status': status.apiValue});

  // ---------------------------------------------------------------------------
  // holidays and pay
  // ---------------------------------------------------------------------------

  Future<List<Holiday>> holidays({DateTime? from, DateTime? to}) async {
    final body = await _client.get('/api/holidays', query: {
      if (from != null) 'from': _ymd(from),
      if (to != null) 'to': _ymd(to),
      'limit': '200',
    });
    return _rows(body).map(Holiday.fromApi).toList();
  }

  /// The signed-in person's payslips, newest month first.
  Future<List<PayrollSummary>> payrolls() async {
    final body =
        await _client.get('/api/payrolls/mine', query: {'limit': '60'});
    final data = body['data'];
    final list = data is Map<String, dynamic> ? data['payrolls'] : data;
    return list is List
        ? list
            .whereType<Map<String, dynamic>>()
            .map(PayrollSummary.fromApi)
            .toList()
        : const [];
  }

  Future<Payslip> payslip(String id) async {
    final body = await _client.get('/api/payrolls/$id');
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException('The server sent something the app could not read.');
    }
    return Payslip.fromApi(data);
  }

  static List<Map<String, dynamic>> _rows(Map<String, dynamic> body) {
    final data = body['data'];
    return data is List
        ? data.whereType<Map<String, dynamic>>().toList()
        : const [];
  }

  static String _ymd(DateTime day) => '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}
