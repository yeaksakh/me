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

  Map<String, dynamic> toJson() => {
        'label': label,
        'line1': line1,
        'city': city,
        'contactName': contactName,
        'contactPhone': contactPhone,
      };

  factory Address.fromJson(Map<String, dynamic> json) => Address(
        label: json['label'] as String,
        line1: json['line1'] as String,
        city: json['city'] as String,
        contactName: json['contactName'] as String?,
        contactPhone: json['contactPhone'] as String?,
      );
}
