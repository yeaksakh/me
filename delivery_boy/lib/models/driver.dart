/// The signed-in rider.
class Driver {
  const Driver({
    required this.id,
    required this.name,
    required this.phone,
    required this.vehicle,
    required this.rating,
    required this.joinedOn,
  });

  final String id;
  final String name;
  final String phone;
  final String vehicle;
  final double rating;
  final DateTime joinedOn;

  /// One or two letters for the avatar badge.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'))
      ..removeWhere((part) => part.isEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
