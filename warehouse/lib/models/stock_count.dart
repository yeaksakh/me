import 'stock_item.dart';

/// One line of a stock count: what the system thought was there, and what the
/// person actually found.
///
/// [expected] is frozen when the line is opened rather than read live, so a
/// variance means "the shelf disagreed with the book at the moment of counting"
/// and not "an order shipped while you were walking the aisle".
class CountLine {
  CountLine({
    required this.stockItemId,
    required this.sku,
    required this.name,
    required this.expected,
    this.variant,
    this.location,
    this.counted,
  });

  final String stockItemId;
  final String sku;
  final String name;
  final String? variant;
  final String? location;

  /// On-hand at the moment this line was opened.
  final int expected;

  /// What was counted. Null until someone enters a number -- which is different
  /// from counting zero, and the difference is the whole point: an uncounted
  /// line is skipped, a zero line writes the shelf down to nothing.
  int? counted;

  bool get isCounted => counted != null;

  /// Counted minus expected. Null while uncounted; positive means a surplus.
  int? get variance => counted == null ? null : counted! - expected;

  bool get hasVariance => (variance ?? 0) != 0;

  String get displayName => variant == null ? name : '$name  ·  $variant';

  Map<String, dynamic> toJson() => {
        'stockItemId': stockItemId,
        'sku': sku,
        'name': name,
        'variant': variant,
        'location': location,
        'expected': expected,
        'counted': counted,
      };

  factory CountLine.fromJson(Map<String, dynamic> json) => CountLine(
        stockItemId: json['stockItemId'] as String,
        sku: json['sku'] as String,
        name: json['name'] as String,
        variant: json['variant'] as String?,
        location: json['location'] as String?,
        expected: json['expected'] as int,
        counted: json['counted'] as int?,
      );

  factory CountLine.forItem(StockItem item) => CountLine(
        stockItemId: item.id,
        sku: item.sku,
        name: item.name,
        variant: item.variant,
        location: item.location,
        expected: item.onHand,
      );
}

/// A counting run: open one, walk the shelves entering what you find, submit.
///
/// Nothing moves until [submit]; a half-finished count is a draft that survives
/// a restart, because counting a warehouse rarely fits in one sitting.
class StockCount {
  StockCount({
    required this.id,
    required this.startedAt,
    required this.lines,
    this.submittedAt,
  });

  final String id;
  final DateTime startedAt;
  final List<CountLine> lines;
  DateTime? submittedAt;

  bool get isSubmitted => submittedAt != null;

  int get countedCount => lines.where((line) => line.isCounted).length;

  int get remainingCount => lines.length - countedCount;

  bool get isComplete => remainingCount == 0 && lines.isNotEmpty;

  /// Counted lines that disagreed with the book. These are what a supervisor
  /// actually reads.
  List<CountLine> get variances =>
      lines.where((line) => line.isCounted && line.hasVariance).toList();

  /// Net units gained or lost across the count.
  int get netVariance =>
      lines.fold(0, (sum, line) => sum + (line.variance ?? 0));

  /// Units of disagreement regardless of direction -- the honest measure of how
  /// wrong the book was, since +5 on one line and -5 on another is not "fine".
  int get absoluteVariance =>
      lines.fold(0, (sum, line) => sum + (line.variance ?? 0).abs());

  CountLine? lineForCode(String code) {
    final needle = code.trim().toUpperCase();
    if (needle.isEmpty) return null;
    for (final line in lines) {
      if (line.sku.toUpperCase() == needle) return line;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'submittedAt': submittedAt?.toIso8601String(),
        'lines': lines.map((line) => line.toJson()).toList(),
      };

  factory StockCount.fromJson(Map<String, dynamic> json) => StockCount(
        id: json['id'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
        submittedAt: json['submittedAt'] == null
            ? null
            : DateTime.parse(json['submittedAt'] as String),
        lines: (json['lines'] as List<dynamic>)
            .map((line) => CountLine.fromJson(line as Map<String, dynamic>))
            .toList(),
      );
}
