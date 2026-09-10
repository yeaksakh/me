/// One sellable thing in the building, and how many of it there are.
///
/// [onHand] is what is physically on the shelf; [reserved] is what is already
/// spoken for by orders that have not left yet. Sellable stock is the
/// difference, which is the number that matters when someone asks "can we take
/// another one of these?".
class StockItem {
  StockItem({
    required this.id,
    required this.sku,
    required this.name,
    required this.onHand,
    this.variant,
    this.barcode,
    this.location,
    this.reserved = 0,
    this.reorderLevel = 0,
    this.countedAt,
  });

  final String id;
  final String sku;
  final String name;
  final String? variant;

  /// What the scanner reads. Null where the shop has not labelled the product.
  final String? barcode;

  /// Bin or shelf, e.g. "A-12-3".
  final String? location;

  /// Units the shelf should be holding.
  int onHand;

  /// Units committed to orders that are still in the building.
  int reserved;

  /// Below this, the item wants reordering. 0 disables the warning.
  final int reorderLevel;

  /// When this item was last counted. Null means never, which is worth showing.
  DateTime? countedAt;

  /// What can still be sold.
  int get available => onHand - reserved;

  bool get isOutOfStock => available <= 0;

  /// Low, but not yet out. An item that is already out is reported as out
  /// rather than low, so the two never both fire for the same row.
  bool get isLow =>
      reorderLevel > 0 && available > 0 && available <= reorderLevel;

  String get displayName => variant == null ? name : '$name  ·  $variant';

  bool matchesCode(String code) {
    final needle = code.trim().toUpperCase();
    if (needle.isEmpty) return false;
    return barcode?.toUpperCase() == needle || sku.toUpperCase() == needle;
  }

  /// Free-text search over the fields a person would actually type.
  bool matchesQuery(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return name.toLowerCase().contains(needle) ||
        sku.toLowerCase().contains(needle) ||
        (variant?.toLowerCase().contains(needle) ?? false) ||
        (location?.toLowerCase().contains(needle) ?? false) ||
        (barcode?.toLowerCase().contains(needle) ?? false);
  }

  StockItem copyWith({int? onHand, int? reserved, DateTime? countedAt}) =>
      StockItem(
        id: id,
        sku: sku,
        name: name,
        variant: variant,
        barcode: barcode,
        location: location,
        onHand: onHand ?? this.onHand,
        reserved: reserved ?? this.reserved,
        reorderLevel: reorderLevel,
        countedAt: countedAt ?? this.countedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'sku': sku,
        'name': name,
        'variant': variant,
        'barcode': barcode,
        'location': location,
        'onHand': onHand,
        'reserved': reserved,
        'reorderLevel': reorderLevel,
        'countedAt': countedAt?.toIso8601String(),
      };

  factory StockItem.fromJson(Map<String, dynamic> json) => StockItem(
        id: json['id'] as String,
        sku: json['sku'] as String,
        name: json['name'] as String,
        variant: json['variant'] as String?,
        barcode: json['barcode'] as String?,
        location: json['location'] as String?,
        onHand: json['onHand'] as int,
        reserved: json['reserved'] as int? ?? 0,
        reorderLevel: json['reorderLevel'] as int? ?? 0,
        countedAt: json['countedAt'] == null
            ? null
            : DateTime.parse(json['countedAt'] as String),
      );
}

/// Why a stock number changed. The backend will want this on every movement --
/// an adjustment without a reason is indistinguishable from a mistake.
enum StockChangeReason { count, damaged, returned, received, correction }

extension StockChangeReasonX on StockChangeReason {
  String get apiValue => name;

  String get label => switch (this) {
        StockChangeReason.count => 'Stock count',
        StockChangeReason.damaged => 'Damaged',
        StockChangeReason.returned => 'Customer return',
        StockChangeReason.received => 'Goods received',
        StockChangeReason.correction => 'Correction',
      };
}
