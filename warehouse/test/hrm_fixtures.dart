import 'package:warehouse/data/api_client.dart';
import 'package:warehouse/data/hrm_api.dart';
import 'package:warehouse/models/hrm.dart';

/// The HR server in memory, with its rules: one open shift at a time, a
/// clock-out needs one open, leave lands as pending.
class FakeHrmApi extends HrmApi {
  FakeHrmApi({
    List<AttendanceEntry>? shifts,
    List<LeaveRequest>? leaves,
    List<Holiday>? holidays,
    List<PayrollSummary>? payrolls,
    this.payslips = const {},
  })  : shifts = shifts ?? [],
        leaveRows = leaves ?? [],
        holidayRows = holidays ?? [],
        payrollRows = payrolls ?? [],
        super(ApiClient());

  final List<AttendanceEntry> shifts;
  final List<LeaveRequest> leaveRows;
  final List<Holiday> holidayRows;
  final List<PayrollSummary> payrollRows;
  final Map<String, Payslip> payslips;

  /// Every clock call, as the server would receive it.
  final List<Map<String, Object?>> punches = [];
  final List<LeaveStatus> statusChanges = [];

  /// Set to answer the next read as an expired session would.
  bool expired = false;

  int _nextId = 100;

  void _guard() {
    if (expired) throw ApiException('This API token has expired.', status: 401);
  }

  @override
  Future<AttendanceEntry?> openShift(String userId) async {
    _guard();
    for (final shift in shifts) {
      if (shift.isOpen) return shift;
    }
    return null;
  }

  @override
  Future<List<AttendanceEntry>> attendance(String userId,
      {required DateTime from, required DateTime to, int limit = 200}) async {
    _guard();
    return shifts
        .where((s) =>
            !s.clockIn.isBefore(from) &&
            s.clockIn.isBefore(to.add(const Duration(days: 1))))
        .toList()
      ..sort((a, b) => b.clockIn.compareTo(a.clockIn));
  }

  @override
  Future<void> clock(String action,
      {String? note,
      double? latitude,
      double? longitude,
      String? photoPath}) async {
    _guard();
    punches.add({
      'action': action,
      'note': note,
      'lat': latitude,
      'lng': longitude,
      'photo': photoPath,
    });
    final open = shifts.indexWhere((s) => s.isOpen);
    if (action == 'in') {
      if (open >= 0) {
        throw ApiException('This user is already clocked in.',
            code: 'already_in');
      }
      shifts.insert(
          0,
          AttendanceEntry(
            id: 'local:${_nextId++}',
            clockIn: DateTime.now(),
            note: note,
            inLatitude: latitude,
            inLongitude: longitude,
          ));
      return;
    }
    if (open < 0) {
      throw ApiException('This user is not clocked in.', code: 'not_in');
    }
    final was = shifts[open];
    shifts[open] = AttendanceEntry(
      id: was.id,
      clockIn: was.clockIn,
      clockOut: DateTime.now(),
      note: was.note,
      outNote: note,
      inLatitude: was.inLatitude,
      inLongitude: was.inLongitude,
    );
  }

  @override
  Future<List<LeaveRequest>> leaves(
      {LeaveStatus? status, int limit = 200}) async {
    _guard();
    return leaveRows
        .where((l) => status == null || l.status == status)
        .toList();
  }

  @override
  Future<List<LeaveType>> leaveTypes() async => const [
        LeaveType(id: 'annual', label: 'ច្បាប់ប្រចាំឆ្នាំ (Annual leave)'),
        LeaveType(id: 'sick', label: 'ច្បាប់ឈឺ (Sick leave)'),
      ];

  @override
  Future<LeaveRequest> requestLeave({
    required String type,
    required DateTime start,
    required DateTime end,
    required String reason,
    bool halfDay = false,
  }) async {
    _guard();
    final leave = LeaveRequest(
      id: '${_nextId++}',
      userName: 'Sokha Chan',
      type: type,
      typeLabel: type == 'sick' ? 'ច្បាប់ឈឺ (Sick leave)' : type,
      start: start,
      end: end,
      totalDays: halfDay ? 0.5 : end.difference(start).inDays + 1,
      isHalfDay: halfDay,
      status: LeaveStatus.pending,
      reason: reason,
    );
    leaveRows.insert(0, leave);
    return leave;
  }

  @override
  Future<void> setLeaveStatus(String id, LeaveStatus status) async {
    _guard();
    statusChanges.add(status);
    final index = leaveRows.indexWhere((l) => l.id == id);
    if (index < 0) throw ApiException('No such leave request.', status: 404);
    final was = leaveRows[index];
    leaveRows[index] = LeaveRequest(
      id: was.id,
      userName: was.userName,
      type: was.type,
      typeLabel: was.typeLabel,
      start: was.start,
      end: was.end,
      totalDays: was.totalDays,
      status: status,
      reason: was.reason,
    );
  }

  @override
  Future<List<Holiday>> holidays({DateTime? from, DateTime? to}) async {
    _guard();
    return holidayRows;
  }

  @override
  Future<List<PayrollSummary>> payrolls() async {
    _guard();
    return payrollRows;
  }

  @override
  Future<Payslip> payslip(String id) async {
    _guard();
    final slip = payslips[id];
    if (slip == null) throw ApiException('No such payroll.', status: 404);
    return slip;
  }
}

AttendanceEntry buildShift({
  String id = 'local:1',
  required DateTime clockIn,
  DateTime? clockOut,
  String? note,
}) =>
    AttendanceEntry(id: id, clockIn: clockIn, clockOut: clockOut, note: note);

LeaveRequest buildLeave({
  String id = 'l1',
  String userName = 'Sokha Chan',
  String typeLabel = 'ច្បាប់ឈឺ (Sick leave)',
  DateTime? start,
  DateTime? end,
  LeaveStatus status = LeaveStatus.pending,
  String reason = 'Fever',
}) {
  final from = start ?? DateTime(2026, 9, 10);
  final to = end ?? from;
  return LeaveRequest(
    id: id,
    userName: userName,
    typeLabel: typeLabel,
    start: from,
    end: to,
    totalDays: to.difference(from).inDays + 1,
    status: status,
    reason: reason,
  );
}
