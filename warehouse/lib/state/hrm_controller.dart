import 'package:flutter/foundation.dart';

import '../data/hrm_api.dart';
import '../models/hrm.dart';

/// The HR side of a shift: clocking in and out, leave, the holidays and pay.
///
/// The server is the record. This keeps what the screens show and turns every
/// refusal into a sentence -- "This user is already clocked in." -- that the
/// button can say.
class HrmController extends ChangeNotifier {
  HrmController(this._api, {required this.userId, this.onUnauthorized});

  final HrmApi _api;

  /// Who is signed in, read late: the handset is shared between shifts.
  final String? Function() userId;

  /// Called when the server says the session is gone.
  final VoidCallback? onUnauthorized;

  AttendanceEntry? _openShift;
  bool _shiftLoaded = false;
  List<AttendanceEntry> _history = const [];
  List<LeaveRequest> _leaves = const [];
  List<LeaveType> _leaveTypes = const [];
  List<Holiday> _holidays = const [];
  List<PayrollSummary> _payrolls = const [];
  bool _busy = false;
  String? _error;

  /// The shift still open, or null when clocked out.
  AttendanceEntry? get openShift => _openShift;
  bool get isClockedIn => _openShift != null;

  /// True once the server has answered whether a shift is open, so the button
  /// does not offer "clock in" to someone it has not checked.
  bool get shiftLoaded => _shiftLoaded;

  List<AttendanceEntry> get history => List.unmodifiable(_history);
  List<LeaveRequest> get leaves => List.unmodifiable(_leaves);
  List<LeaveType> get leaveTypes => List.unmodifiable(_leaveTypes);
  List<Holiday> get holidays => List.unmodifiable(_holidays);
  List<PayrollSummary> get payrolls => List.unmodifiable(_payrolls);

  /// True while a change is on its way to the server, so a double tap cannot
  /// clock someone in twice.
  bool get busy => _busy;
  String? get error => _error;

  // ---------------------------------------------------------------------------
  // attendance
  // ---------------------------------------------------------------------------

  Future<void> loadShift() async {
    final id = userId();
    if (id == null) return;
    await _read(() async {
      _openShift = await _api.openShift(id);
      _shiftLoaded = true;
    });
  }

  /// Shifts between [from] and [to], newest first.
  Future<void> loadHistory({required DateTime from, required DateTime to}) async {
    final id = userId();
    if (id == null) return;
    await _read(() async {
      _history = await _api.attendance(id, from: from, to: to);
    });
  }

  /// Clocks in, or out when a shift is open. Returns the action taken, or
  /// null when it failed and [error] says why.
  Future<String?> clock({
    String? note,
    ({double latitude, double longitude})? position,
    String? photoPath,
  }) async {
    final action = isClockedIn ? 'out' : 'in';
    final done = await _write(() => _api.clock(
          action,
          note: note,
          latitude: position?.latitude,
          longitude: position?.longitude,
          photoPath: photoPath,
        ));
    // Re-read rather than guess: the server stamps the time, and a refusal
    // usually means the state changed elsewhere (the kiosk clocked them in).
    // The refusal's own words survive the re-read, so the button can say them.
    final refusal = done ? null : _error;
    await loadShift();
    if (refusal != null && _error == null) {
      _error = refusal;
      notifyListeners();
    }
    return done ? action : null;
  }

  // ---------------------------------------------------------------------------
  // leave
  // ---------------------------------------------------------------------------

  Future<void> loadLeaves() => _read(() async {
        _leaves = await _api.leaves();
      });

  Future<void> loadLeaveTypes() async {
    if (_leaveTypes.isNotEmpty) return;
    await _read(() async {
      _leaveTypes = await _api.leaveTypes();
    });
  }

  Future<bool> requestLeave({
    required LeaveType type,
    required DateTime start,
    required DateTime end,
    required String reason,
    bool halfDay = false,
  }) async {
    if (reason.trim().isEmpty) {
      _error = 'Say why you need the leave.';
      notifyListeners();
      return false;
    }
    if (end.isBefore(start)) {
      _error = 'The end date is before the start.';
      notifyListeners();
      return false;
    }
    final done = await _write(() => _api.requestLeave(
        type: type.id, start: start, end: end, reason: reason, halfDay: halfDay));
    if (done) await loadLeaves();
    return done;
  }

  Future<bool> setLeaveStatus(String id, LeaveStatus status) async {
    final done = await _write(() => _api.setLeaveStatus(id, status));
    if (done) await loadLeaves();
    return done;
  }

  // ---------------------------------------------------------------------------
  // holidays and pay
  // ---------------------------------------------------------------------------

  Future<void> loadHolidays({required int year}) => _read(() async {
        _holidays = await _api.holidays(
            from: DateTime(year, 1, 1), to: DateTime(year, 12, 31));
      });

  Future<void> loadPayrolls() => _read(() async {
        _payrolls = await _api.payrolls();
      });

  /// One payslip. Not kept: it is the size of a page and read once.
  Future<Payslip?> payslip(String id) async {
    try {
      return await _api.payslip(id);
    } on ApiException catch (failure) {
      _fail(failure);
      notifyListeners();
      return null;
    }
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<void> _read(Future<void> Function() load) async {
    _error = null;
    try {
      await load();
    } on ApiException catch (failure) {
      _fail(failure);
    } finally {
      notifyListeners();
    }
  }

  Future<bool> _write(Future<void> Function() send) async {
    if (_busy) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await send();
      return true;
    } on ApiException catch (failure) {
      _fail(failure);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void _fail(ApiException failure) {
    _error = failure.message;
    if (failure.isUnauthorized) onUnauthorized?.call();
  }
}
