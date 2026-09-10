// Small display helpers, kept dependency-free so the app has no intl setup.

String clockTime(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final suffix = time.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $suffix';
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String shortDate(DateTime date) => '${_months[date.month - 1]} ${date.day}';

/// "Sep 10, 3:15 PM" -- a moment on a shipment's record.
String dateTime(DateTime time) => '${shortDate(time)}, ${clockTime(time)}';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Thu, Sep 10 2026" -- a day on a calendar.
String longDate(DateTime date) =>
    '${_weekdays[date.weekday - 1]}, ${shortDate(date)} ${date.year}';

/// "Sep 10 – Sep 12", or one date when both are the same day.
String dateRange(DateTime start, DateTime end) => isSameDay(start, end)
    ? shortDate(start)
    : '${shortDate(start)} – ${shortDate(end)}';

/// "3h 12m", "45m" -- time worked.
String hoursMinutes(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  if (hours == 0) return '${minutes}m';
  return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
}

/// "September 2026" for a `YYYY-MM` payroll month.
String monthLabel(String yearMonth) {
  final parts = yearMonth.split('-');
  if (parts.length < 2) return yearMonth;
  final month = int.tryParse(parts[1]);
  if (month == null || month < 1 || month > 12) return yearMonth;
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${names[month - 1]} ${parts[0]}';
}

/// "$412.75", "៛1,650,000" -- money with the shop's symbol and thousands.
String money(double amount, {String symbol = r'$'}) {
  final whole = amount.abs().truncate();
  final cents = ((amount.abs() - whole) * 100).round();
  final digits = whole.toString();
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
    grouped.write(digits[i]);
  }
  final body = cents == 0
      ? grouped.toString()
      : '$grouped.${cents.toString().padLeft(2, '0')}';
  return '${amount < 0 ? '-' : ''}$symbol$body';
}

/// "12 min ago" style text for order queues.
String relativeTime(DateTime time, {DateTime? now}) {
  final difference = (now ?? DateTime.now()).difference(time);
  if (difference.inMinutes < 1) return 'just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
  if (difference.inHours < 24) return '${difference.inHours} h ago';
  return '${difference.inDays} d ago';
}

/// How long something has been waiting, for a queue where age is the point.
String waitingFor(DateTime since, {DateTime? now}) {
  final difference = (now ?? DateTime.now()).difference(since);
  if (difference.inMinutes < 1) return 'just in';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m';
  if (difference.inHours < 24) {
    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;
    return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }
  return '${difference.inDays}d';
}

/// A signed number, for variances where the sign carries the meaning.
String signed(int value) => value > 0 ? '+$value' : '$value';

/// "3 items" / "1 item".
String plural(int count, String singular, [String? pluralForm]) =>
    count == 1 ? '1 $singular' : '$count ${pluralForm ?? '${singular}s'}';

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
