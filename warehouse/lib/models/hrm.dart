/// The HRM records a staff member sees: their attendance, leave, the holidays,
/// and their pay -- as `/api/attendance`, `/api/leaves`, `/api/holidays` and
/// `/api/payrolls` send them.
library;

String? _text(Object? value) {
  if (value == null) return null;
  final text = '$value'.trim();
  return text.isEmpty ? null : text;
}

double? _num(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value');

/// The server marks its timestamps with a zone, so this is the phone's local time.
DateTime? _when(Object? value) => value is String && value.isNotEmpty
    ? DateTime.tryParse(value)?.toLocal()
    : null;

/// A bare `YYYY-MM-DD`, kept as a local calendar day.
DateTime? _day(Object? value) {
  if (value is! String || value.length < 10) return null;
  final parsed = DateTime.tryParse(value.substring(0, 10));
  return parsed == null
      ? null
      : DateTime(parsed.year, parsed.month, parsed.day);
}

/// One shift: a clock-in and, once it is over, a clock-out.
class AttendanceEntry {
  const AttendanceEntry({
    required this.id,
    required this.clockIn,
    this.clockOut,
    this.note,
    this.outNote,
    this.inLatitude,
    this.inLongitude,
    this.outLatitude,
    this.outLongitude,
    this.inPhotoUrl,
    this.outPhotoUrl,
  });

  final String id;
  final DateTime clockIn;
  final DateTime? clockOut;
  final String? note;
  final String? outNote;
  final double? inLatitude;
  final double? inLongitude;
  final double? outLatitude;
  final double? outLongitude;
  final String? inPhotoUrl;
  final String? outPhotoUrl;

  bool get isOpen => clockOut == null;

  /// How long the shift ran, or has run so far.
  Duration get worked => (clockOut ?? DateTime.now()).difference(clockIn);

  factory AttendanceEntry.fromApi(Map<String, dynamic> json) => AttendanceEntry(
        id: '${json['source'] ?? 'local'}:${json['id']}',
        clockIn: _when(json['clock_in_time']) ?? DateTime.now(),
        clockOut: _when(json['clock_out_time']),
        note: _text(json['clock_in_note']),
        outNote: _text(json['clock_out_note']),
        inLatitude: _num(json['clock_in_lat']),
        inLongitude: _num(json['clock_in_lng']),
        outLatitude: _num(json['clock_out_lat']),
        outLongitude: _num(json['clock_out_lng']),
        inPhotoUrl: _text(json['clock_in_photo']),
        outPhotoUrl: _text(json['clock_out_photo']),
      );
}

/// A kind of leave the shop recognises. [id] is the key the server wants back.
class LeaveType {
  const LeaveType({required this.id, required this.label});

  final String id;

  /// Khmer and English together, as the server labels it: "ច្បាប់ឈឺ (Sick leave)".
  final String label;

  factory LeaveType.fromApi(Map<String, dynamic> json) => LeaveType(
        id: _text(json['id']) ?? _text(json['key']) ?? '',
        label: _text(json['leave_type']) ??
            _text(json['name_en']) ??
            _text(json['id']) ??
            '',
      );
}

enum LeaveStatus { pending, approved, rejected, cancelled }

extension LeaveStatusX on LeaveStatus {
  String get apiValue => name;

  String get label => switch (this) {
        LeaveStatus.pending => 'Pending',
        LeaveStatus.approved => 'Approved',
        LeaveStatus.rejected => 'Rejected',
        LeaveStatus.cancelled => 'Cancelled',
      };
}

LeaveStatus leaveStatusFromApi(Object? value) =>
    switch ('$value'.toLowerCase()) {
      'approved' => LeaveStatus.approved,
      'rejected' => LeaveStatus.rejected,
      'cancelled' => LeaveStatus.cancelled,
      _ => LeaveStatus.pending,
    };

class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.userName,
    required this.typeLabel,
    required this.start,
    required this.end,
    required this.totalDays,
    required this.status,
    this.refNo = '',
    this.type = '',
    this.isHalfDay = false,
    this.reason = '',
    this.adminRemarks = '',
    this.createdAt,
  });

  final String id;
  final String refNo;
  final String userName;
  final String type;
  final String typeLabel;
  final DateTime start;
  final DateTime end;
  final double totalDays;
  final bool isHalfDay;
  final LeaveStatus status;
  final String reason;
  final String adminRemarks;
  final DateTime? createdAt;

  String get daysLabel =>
      totalDays == totalDays.truncateToDouble() && totalDays >= 1
          ? '${totalDays.toInt()} day${totalDays == 1 ? '' : 's'}'
          : isHalfDay
              ? 'Half day'
              : '$totalDays days';

  factory LeaveRequest.fromApi(Map<String, dynamic> json) {
    final start = _day(json['start_date']) ?? DateTime.now();
    return LeaveRequest(
      id: '${json['id']}',
      refNo: _text(json['ref_no']) ?? '#${json['id']}',
      userName: _text(json['user_name']) ?? '',
      type: _text(json['leave_type']) ?? '',
      typeLabel:
          _text(json['leave_type_label']) ?? _text(json['leave_type']) ?? '',
      start: start,
      end: _day(json['end_date']) ?? start,
      totalDays: _num(json['total_days']) ?? 1,
      isHalfDay: json['is_half_day'] == true,
      status: leaveStatusFromApi(json['status']),
      reason: _text(json['reason']) ?? '',
      adminRemarks: _text(json['admin_remarks']) ?? '',
      createdAt: _when(json['created_at']),
    );
  }
}

class Holiday {
  const Holiday({
    required this.id,
    required this.name,
    required this.start,
    required this.end,
    this.type = '',
    this.note = '',
  });

  final String id;
  final String name;
  final String type;
  final DateTime start;
  final DateTime end;
  final String note;

  int get days => end.difference(start).inDays + 1;

  factory Holiday.fromApi(Map<String, dynamic> json) {
    final start = _day(json['start_date']) ?? DateTime.now();
    return Holiday(
      id: '${json['id']}',
      name: _text(json['name']) ?? 'Holiday',
      type: _text(json['holiday_type']) ?? '',
      start: start,
      end: _day(json['end_date']) ?? start,
      note: _text(json['note']) ?? '',
    );
  }
}

/// One month's pay, as the list shows it.
class PayrollSummary {
  const PayrollSummary({
    required this.id,
    required this.month,
    required this.netPay,
    this.basicSalary = 0,
    this.allowances = 0,
    this.deductions = 0,
    this.status = '',
    this.paidOn,
  });

  final String id;

  /// `YYYY-MM`.
  final String month;
  final double netPay;
  final double basicSalary;
  final double allowances;
  final double deductions;
  final String status;
  final DateTime? paidOn;

  factory PayrollSummary.fromApi(Map<String, dynamic> json) => PayrollSummary(
        id: '${json['id']}',
        month: _text(json['month']) ?? '',
        netPay: _num(json['net_pay']) ?? _num(json['final_total']) ?? 0,
        basicSalary: _num(json['basic_salary']) ?? 0,
        allowances: _num(json['allowances']) ?? 0,
        deductions: _num(json['deductions']) ?? 0,
        status: _text(json['payment_status']) ?? '',
        paidOn: _day(json['paid_on']),
      );
}

/// One row of the payslip's maths.
class PayLine {
  const PayLine(
      {required this.label,
      required this.amount,
      this.kind = 'add',
      this.when = ''});

  final String label;
  final double amount;

  /// `base`, `add` or `minus`.
  final String kind;
  final String when;

  bool get isDeduction => kind == 'minus';
}

/// The payslip, as far as a phone shows it: the maths, the month's work, the
/// leave that counted, and whether it has been paid.
class Payslip {
  const Payslip({
    required this.id,
    required this.monthLabel,
    required this.netPay,
    this.basicSalary = 0,
    this.totalEarnings = 0,
    this.totalDeductions = 0,
    this.lines = const [],
    this.presentDays,
    this.absentDays,
    this.scheduledDays,
    this.lateMinutes,
    this.clockedHours,
    this.shift = '',
    this.paidLeaveDays,
    this.unpaidLeaveDays,
    this.absentDates = const [],
    this.leaves = const [],
    this.paidOn,
    this.paidBy = '',
    this.employeeName = '',
  });

  final String id;
  final String monthLabel;
  final double netPay;
  final double basicSalary;
  final double totalEarnings;
  final double totalDeductions;
  final List<PayLine> lines;
  final double? presentDays;
  final double? absentDays;
  final double? scheduledDays;
  final double? lateMinutes;
  final double? clockedHours;
  final String shift;
  final double? paidLeaveDays;
  final double? unpaidLeaveDays;
  final List<String> absentDates;
  final List<LeaveRequest> leaves;
  final DateTime? paidOn;
  final String paidBy;
  final String employeeName;

  bool get isPaid => paidOn != null;

  factory Payslip.fromApi(Map<String, dynamic> json) {
    final work = json['work'] is Map<String, dynamic>
        ? json['work'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final payment = json['payment'] is Map<String, dynamic>
        ? json['payment'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final employee = json['employee'] is Map<String, dynamic>
        ? json['employee'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final basic = json['basic_salary'];
    final seconds = _num(work['clocked_seconds']);
    return Payslip(
      id: '${json['id']}',
      monthLabel: _text(json['month_label']) ?? _text(json['month']) ?? '',
      netPay: _num(json['net_pay']) ?? _num(json['final_total']) ?? 0,
      basicSalary: basic is Map<String, dynamic>
          ? (_num(basic['amount']) ?? 0)
          : (_num(basic) ?? 0),
      totalEarnings: _num(json['total_earnings']) ?? 0,
      totalDeductions: _num(json['total_deductions']) ?? 0,
      lines: json['lines'] is List
          ? (json['lines'] as List)
              .whereType<Map<String, dynamic>>()
              .map((line) => PayLine(
                    label: _text(line['label']) ?? '',
                    amount: _num(line['amount']) ?? 0,
                    kind: _text(line['kind']) ?? 'add',
                    when: _text(line['when']) ?? '',
                  ))
              .toList()
          : const [],
      presentDays: _num(work['present_days']),
      absentDays: _num(work['absent_days']),
      scheduledDays: _num(work['scheduled_days']),
      lateMinutes: _num(work['late_minutes']),
      clockedHours: seconds == null ? null : seconds / 3600,
      shift: _text(work['shift']) ?? '',
      paidLeaveDays: _num(work['paid_leave_days']),
      unpaidLeaveDays: _num(work['unpaid_leave_days']),
      absentDates: work['absent_dates'] is List
          ? (work['absent_dates'] as List).map((d) => '$d').toList()
          : const [],
      leaves: json['leaves'] is List
          ? (json['leaves'] as List)
              .whereType<Map<String, dynamic>>()
              .map(LeaveRequest.fromApi)
              .toList()
          : const [],
      paidOn: _day(payment['paid_on'] ?? json['paid_on']),
      paidBy: _text(payment['paid_by']) ?? '',
      employeeName: _text(employee['full_name']) ?? '',
    );
  }
}
