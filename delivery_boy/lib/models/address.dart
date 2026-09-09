/// A physical location involved in a delivery (a pickup point or a drop point).
class Address {
  const Address({
    required this.label,
    required this.line1,
    required this.city,
    this.contactName,
    this.contactPhone,
  });

  /// Short human name, e.g. "Spice Garden" or "Home".
  final String label;
  final String line1;
  final String city;
  final String? contactName;
  final String? contactPhone;

  String get full => '$line1, $city';
}
