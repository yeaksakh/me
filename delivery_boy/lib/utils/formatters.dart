// Small display helpers, kept dependency-free so the app has no intl setup.

String money(double value) => '\$${value.toStringAsFixed(2)}';

String distance(double km) => '${km.toStringAsFixed(1)} km';

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

/// "12 min ago" style text for order feeds.
String relativeTime(DateTime time, {DateTime? now}) {
  final difference = (now ?? DateTime.now()).difference(time);
  if (difference.inMinutes < 1) return 'just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
  if (difference.inHours < 24) return '${difference.inHours} h ago';
  return '${difference.inDays} d ago';
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
