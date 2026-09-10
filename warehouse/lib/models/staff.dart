/// What a signed-in person is allowed to do.
///
/// The split that matters on the floor is who may close a check: a packer
/// preparing an order and then signing off their own work is exactly the
/// control a second stage exists to provide.
enum StaffRole { packer, checker, supervisor }

extension StaffRoleX on StaffRole {
  String get apiValue => name;

  String get label => switch (this) {
        StaffRole.packer => 'Packer',
        StaffRole.checker => 'Checker',
        StaffRole.supervisor => 'Supervisor',
      };

  /// May move an order `ordered` -> `prepared`.
  bool get canPrepare => true;

  /// May move an order `prepared` -> `checked`.
  bool get canCheck =>
      this == StaffRole.checker || this == StaffRole.supervisor;

  /// May write stock numbers -- adjustments and submitting a count.
  bool get canAdjustStock =>
      this == StaffRole.checker || this == StaffRole.supervisor;
}

StaffRole staffRoleFromApi(Object? value) {
  for (final role in StaffRole.values) {
    if (role.apiValue == value) return role;
  }
  return StaffRole.packer;
}

/// The signed-in warehouse staff member.
class Staff {
  const Staff({
    required this.id,
    required this.name,
    required this.role,
    required this.warehouseName,
    this.username,
  });

  final String id;
  final String name;
  final StaffRole role;

  /// Which building they are standing in. Shown in the app bar, because a
  /// multi-warehouse shop will eventually have someone in the wrong one.
  final String warehouseName;

  /// The yeaksa.com username they signed in with.
  final String? username;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'))
      ..removeWhere((part) => part.isEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role.apiValue,
        'warehouseName': warehouseName,
        'username': username,
      };

  factory Staff.fromJson(Map<String, dynamic> json) => Staff(
        id: json['id'] as String,
        name: json['name'] as String,
        role: staffRoleFromApi(json['role']),
        warehouseName: json['warehouseName'] as String,
        username: json['username'] as String?,
      );
}
