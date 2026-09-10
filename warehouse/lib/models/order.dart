import 'fulfilment_stage.dart';

/// Whether the money is already in. Mirrors the backend's `payment_status`.
///
/// It matters on the floor: an unpaid order is cash on delivery, and the packer
/// needs to know before it leaves that the rider has to collect at the door.
enum PaymentStatus { paid, unpaid }

extension PaymentStatusX on PaymentStatus {
  String get apiValue => this == PaymentStatus.paid ? 'paid' : 'unpaid';
  String get label =>
      this == PaymentStatus.paid ? 'Paid online' : 'Cash on delivery';
  String get shortLabel => this == PaymentStatus.paid ? 'Paid' : 'COD';
}

PaymentStatus paymentStatusFromApi(Object? value) =>
    value == 'paid' ? PaymentStatus.paid : PaymentStatus.unpaid;

/// One product line on an order, and how much of it is in the box so far.
///
/// [picked] is the packer's running tally, kept per line rather than as a single
/// "done" flag so a part-picked order survives a restart with its progress --
/// the common case being a line that is short and needs a supervisor.
class OrderLine {
  OrderLine({
    required this.id,
    required this.sku,
    required this.name,
    required this.quantity,
    this.variant,
    this.barcode,
    this.location,
    int picked = 0,
  }) : picked = picked.clamp(0, quantity);

  final String id;
  final String sku;
  final String name;

  /// How many the customer ordered.
  final int quantity;

  /// e.g. "Red / XL". Null on a product without variants.
  final String? variant;

  /// What the scanner reads. Null until the backend carries barcodes -- the
  /// line is still pickable by hand, it just cannot be scanned.
  final String? barcode;

  /// Where to walk to, e.g. "A-12-3". Null when the shop does not bin its stock.
  final String? location;

  /// How many are in the box. Never above [quantity].
  int picked;

  bool get isComplete => picked >= quantity;
  bool get isUntouched => picked == 0;

  /// Short of what was ordered, but not empty -- the state a packer has to
  /// resolve before the order can move on.
  bool get isShort => picked > 0 && picked < quantity;

  int get remaining => quantity - picked;

  String get displayName => variant == null ? name : '$name  ·  $variant';

  /// True when [code] identifies this line. Falls back to the SKU so a shop
  /// that prints SKUs rather than barcodes still scans.
  bool matchesCode(String code) {
    final needle = code.trim().toUpperCase();
    if (needle.isEmpty) return false;
    return barcode?.toUpperCase() == needle || sku.toUpperCase() == needle;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sku': sku,
        'name': name,
        'quantity': quantity,
        'variant': variant,
        'barcode': barcode,
        'location': location,
        'picked': picked,
      };

  factory OrderLine.fromJson(Map<String, dynamic> json) => OrderLine(
        id: json['id'] as String,
        sku: json['sku'] as String,
        name: json['name'] as String,
        quantity: json['quantity'] as int,
        variant: json['variant'] as String?,
        barcode: json['barcode'] as String?,
        location: json['location'] as String?,
        picked: json['picked'] as int? ?? 0,
      );
}

/// An order as the warehouse sees it: what to pick, where it is going, and
/// which stage of `core/api/shop/orders.py::STAGES` it currently sits at.
class Order {
  Order({
    required this.id,
    required this.code,
    required this.customerName,
    required this.shippingAddress,
    required this.lines,
    required this.placedAt,
    required this.paymentStatus,
    this.customerPhone,
    this.stage = FulfilmentStage.ordered,
    this.preparedAt,
    this.checkedAt,
    this.staffNote,
  });

  final String id;

  /// The human reference, e.g. "YK-20419" -- what is written on the box.
  final String code;
  final String customerName;
  final String? customerPhone;
  final String shippingAddress;
  final List<OrderLine> lines;
  final DateTime placedAt;
  final PaymentStatus paymentStatus;

  FulfilmentStage stage;
  DateTime? preparedAt;
  DateTime? checkedAt;

  /// Anything the packer had to say -- a short pick, a damaged item, a
  /// substitution. Travels with the order so the checker sees it.
  String? staffNote;

  /// Units ordered, not lines.
  int get unitCount => lines.fold(0, (sum, line) => sum + line.quantity);

  int get pickedCount => lines.fold(0, (sum, line) => sum + line.picked);

  int get lineCount => lines.length;

  /// Every line has its full quantity in the box.
  bool get isFullyPicked => lines.every((line) => line.isComplete);

  /// At least one line came up short. The order can still go, but not silently.
  bool get hasShortage => lines.any((line) => !line.isComplete);

  /// 0..1, by units rather than lines, so a big line counts for more.
  double get pickProgress {
    final total = unitCount;
    if (total == 0) return 1;
    return pickedCount / total;
  }

  /// Cash orders need the rider to collect; prepaid ones do not.
  bool get isCashOnDelivery => paymentStatus == PaymentStatus.unpaid;

  OrderLine? lineById(String lineId) {
    for (final line in lines) {
      if (line.id == lineId) return line;
    }
    return null;
  }

  /// The first unfinished line matching a scanned code.
  ///
  /// Prefers an incomplete line so scanning the same barcode twice fills the
  /// second unit rather than bouncing off a line that is already done.
  OrderLine? lineForCode(String code) {
    OrderLine? fallback;
    for (final line in lines) {
      if (!line.matchesCode(code)) continue;
      if (!line.isComplete) return line;
      fallback ??= line;
    }
    return fallback;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'shippingAddress': shippingAddress,
        'lines': lines.map((line) => line.toJson()).toList(),
        'placedAt': placedAt.toIso8601String(),
        'paymentStatus': paymentStatus.apiValue,
        'stage': stage.apiValue,
        'preparedAt': preparedAt?.toIso8601String(),
        'checkedAt': checkedAt?.toIso8601String(),
        'staffNote': staffNote,
      };

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as String,
        code: json['code'] as String,
        customerName: json['customerName'] as String,
        customerPhone: json['customerPhone'] as String?,
        shippingAddress: json['shippingAddress'] as String,
        lines: (json['lines'] as List<dynamic>)
            .map((line) => OrderLine.fromJson(line as Map<String, dynamic>))
            .toList(),
        placedAt: DateTime.parse(json['placedAt'] as String),
        paymentStatus: paymentStatusFromApi(json['paymentStatus']),
        stage: stageFromApi(json['stage']),
        preparedAt: json['preparedAt'] == null
            ? null
            : DateTime.parse(json['preparedAt'] as String),
        checkedAt: json['checkedAt'] == null
            ? null
            : DateTime.parse(json['checkedAt'] as String),
        staffNote: json['staffNote'] as String?,
      );
}
