// Small display helpers, kept dependency-free so the app has no intl setup.

String clockTime(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final suffix = time.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $suffix';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String shortDate(DateTime date) => '${_months[date.month - 1]} ${date.day}';

/// "Sep 10, 3:15 PM" -- a moment on a shipment's record.
String dateTime(DateTime time) => '${shortDate(time)}, ${clockTime(time)}';

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
