import 'fulfilment_stage.dart';

/// Whether the money is in. Mirrors the ERP's `payment_status`.
///
/// Anything short of `paid` means money changes hands at the door, so the invoice
/// goes in the box and the rider knows to collect.
enum PaymentStatus { paid, partial, due }

extension PaymentStatusX on PaymentStatus {
  String get label => switch (this) {
        PaymentStatus.paid => 'Paid',
        PaymentStatus.partial => 'Part paid — collect the rest',
        PaymentStatus.due => 'Not paid — collect on delivery',
      };
}

PaymentStatus paymentStatusFromApi(Object? value) =>
    switch ('$value'.trim().toLowerCase()) {
      'paid' => PaymentStatus.paid,
      'partial' => PaymentStatus.partial,
      _ => PaymentStatus.due,
    };

/// A staff member as a shipment names them: who accepted it, who packed an item.
class StaffRef {
  const StaffRef({required this.id, required this.name});

  /// The yeaksa.com user id, as text -- the same form `Staff.id` takes.
  final String id;
  final String name;

  static StaffRef? fromApi(Object? json) {
    if (json is! Map<String, dynamic> || json['id'] == null) return null;
    return StaffRef(id: '${json['id']}', name: _text(json['name']) ?? '');
  }
}

/// A photo filed against a shipment, and the status it is evidence for.
class OrderPhoto {
  const OrderPhoto({required this.url, this.stage});

  final String url;
  final FulfilmentStage? stage;
}

/// One item on a shipment, and whether it is in the box.
///
/// Packed is a tick per item, not a count, because that is what the website
/// records (`transaction_sell_lines.packed_by`) and what its Packed button waits on.
class OrderLine {
  const OrderLine({
    required this.id,
    required this.name,
    required this.quantity,
    this.sku = '',
    this.variant,
    this.parentId,
    this.imageUrl,
    this.rack = '',
    this.row = '',
    this.position = '',
    this.packed = false,
    this.packedBy,
    this.packedAt,
  });

  final String id;

  /// Set on the items inside a bundle: the line of the bundle they belong to.
  final String? parentId;

  final String name;

  /// e.g. "700 ml". Null on a product without variations.
  final String? variant;

  final String sku;

  /// The ERP sells by weight and length as well as by the piece, so this is not
  /// always whole.
  final double quantity;

  final String? imageUrl;

  /// Where it sits at this branch, from the ERP's product racks. Any of the
  /// three may be blank.
  final String rack;
  final String row;
  final String position;

  final bool packed;
  final StaffRef? packedBy;
  final DateTime? packedAt;

  bool get isBundleItem => parentId != null;

  bool get hasLocation =>
      rack.isNotEmpty || row.isNotEmpty || position.isNotEmpty;

  /// The shelf to walk to, spelt out -- "Rack K · Row K6/0 · Position K6" --
  /// or null when the shop has not binned this product.
  String? get location {
    if (!hasLocation) return null;
    return [
      if (rack.isNotEmpty) 'Rack $rack',
      if (row.isNotEmpty) 'Row $row',
      if (position.isNotEmpty) 'Position $position',
    ].join('  ·  ');
  }

  String get displayName => variant == null ? name : '$name  ·  $variant';

  /// Whole quantities without a decimal point, which is how they are counted.
  String get quantityLabel => quantity == quantity.truncateToDouble()
      ? '${quantity.toInt()}'
      : '$quantity';

  /// True when a scanned [code] is this item's SKU.
  bool matchesCode(String code) {
    final needle = code.trim().toUpperCase();
    return needle.isNotEmpty && sku.toUpperCase() == needle;
  }

  OrderLine copyWith({
    bool? packed,
    StaffRef? packedBy,
    bool clearPackedBy = false,
  }) =>
      OrderLine(
        id: id,
        parentId: parentId,
        name: name,
        variant: variant,
        sku: sku,
        quantity: quantity,
        imageUrl: imageUrl,
        rack: rack,
        row: row,
        position: position,
        packed: packed ?? this.packed,
        packedBy: clearPackedBy ? null : (packedBy ?? this.packedBy),
        packedAt: packedAt,
      );

  factory OrderLine.fromApi(Map<String, dynamic> json) {
    return OrderLine(
      id: '${json['id']}',
      parentId: json['parent_id'] == null ? null : '${json['parent_id']}',
      name: _text(json['product']) ?? 'Item',
      variant: _text(json['variation']),
      sku: _text(json['sku']) ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      imageUrl: _text(json['image']),
      rack: _text(json['rack']) ?? '',
      row: _text(json['row']) ?? '',
      position: _text(json['position']) ?? '',
      packed: json['packed'] == true,
      packedBy: StaffRef.fromApi(json['packed_by']),
      packedAt: _date(json['packed_at']),
    );
  }
}

/// A shipment as the warehouse sees it: where it is in the flow, who has it, and
/// -- once opened -- every item to put in the box.
class Order {
  const Order({
    required this.id,
    required this.code,
    required this.customerName,
    required this.placedAt,
    this.stage = FulfilmentStage.ordered,
    this.customerPhone = '',
    this.shippingAddress = '',
    this.locationName = '',
    this.paymentStatus = PaymentStatus.paid,
    this.amountDue = 0,
    this.note = '',
    this.preparedBy,
    this.lineCount = 0,
    this.packedCount = 0,
    this.totalQuantity = 0,
    this.lines = const [],
    this.photos = const [],
    this.hasDetail = false,
  });

  final String id;

  /// The invoice number -- what is written on the box.
  final String code;
  final String customerName;

  /// Empty while the shipment is `ordered`: the server withholds the phone and
  /// address from packers, as the website does.
  final String customerPhone;
  final String shippingAddress;

  /// The branch the sale belongs to.
  final String locationName;

  final DateTime placedAt;
  final FulfilmentStage stage;
  final PaymentStatus paymentStatus;
  final double amountDue;

  /// The sale's own note, from whoever rang it up.
  final String note;

  /// Who accepted it to pack -- the website's "Will be prepared".
  final StaffRef? preparedBy;

  final int lineCount;
  final int packedCount;
  final double totalQuantity;

  /// Empty on a list row; filled once the shipment is opened.
  final List<OrderLine> lines;
  final List<OrderPhoto> photos;

  /// True when [lines] and [photos] were loaded, rather than simply empty.
  final bool hasDetail;

  bool get isCashOnDelivery => paymentStatus != PaymentStatus.paid;

  bool get isAccepted => preparedBy != null;

  bool isAcceptedBy(String? staffId) =>
      staffId != null && preparedBy?.id == staffId;

  /// Every item ticked -- what Packed waits on.
  bool get isFullyPacked => lineCount > 0 && packedCount >= lineCount;

  int get unpackedCount => (lineCount - packedCount).clamp(0, lineCount);

  double get packProgress => lineCount == 0 ? 0 : packedCount / lineCount;

  OrderLine? lineById(String lineId) {
    for (final line in lines) {
      if (line.id == lineId) return line;
    }
    return null;
  }

  /// The item a scanned code belongs to, preferring one not yet ticked, so the
  /// same SKU on two lines fills the second rather than bouncing off the first.
  OrderLine? lineForCode(String code) {
    OrderLine? fallback;
    for (final line in lines) {
      if (!line.matchesCode(code)) continue;
      if (!line.packed) return line;
      fallback ??= line;
    }
    return fallback;
  }

  Order copyWith({
    FulfilmentStage? stage,
    StaffRef? preparedBy,
    bool clearPreparedBy = false,
    List<OrderLine>? lines,
  }) {
    final nextLines = lines ?? this.lines;
    return Order(
      id: id,
      code: code,
      customerName: customerName,
      placedAt: placedAt,
      stage: stage ?? this.stage,
      customerPhone: customerPhone,
      shippingAddress: shippingAddress,
      locationName: locationName,
      paymentStatus: paymentStatus,
      amountDue: amountDue,
      note: note,
      preparedBy: clearPreparedBy ? null : (preparedBy ?? this.preparedBy),
      lineCount: lines == null ? lineCount : nextLines.length,
      packedCount: lines == null
          ? packedCount
          : nextLines.where((line) => line.packed).length,
      totalQuantity: totalQuantity,
      lines: nextLines,
      photos: photos,
      hasDetail: hasDetail,
    );
  }

  /// One shipment as `core/api/views_shipments.py` sends it -- a list row, or a
  /// detail when it carries `items`.
  factory Order.fromApi(Map<String, dynamic> json) {
    final items = json['items'];
    final photos = json['photos'];
    final location = json['location'];
    return Order(
      id: '${json['id']}',
      // Some ERP rows carry no invoice number; the id is what staff would quote.
      code: _text(json['invoice_no']) ?? '#${json['id']}',
      customerName:
          _text(json['customer']) ?? _text(json['customer_name']) ?? 'Customer',
      customerPhone: _text(json['customer_phone']) ?? '',
      shippingAddress: _text(json['address']) ?? '',
      locationName:
          location is Map<String, dynamic> ? (_text(location['name']) ?? '') : '',
      placedAt: _date(json['ordered_at']) ?? DateTime.now(),
      stage: stageFromApi(json['shipping_status']),
      paymentStatus: paymentStatusFromApi(json['payment_status']),
      amountDue: (json['due'] as num?)?.toDouble() ?? 0,
      note: _text(json['note']) ?? '',
      preparedBy: StaffRef.fromApi(json['prepared_by']),
      lineCount: (json['line_count'] as num?)?.toInt() ?? 0,
      packedCount: (json['packed_count'] as num?)?.toInt() ?? 0,
      totalQuantity: (json['total_quantity'] as num?)?.toDouble() ?? 0,
      lines: items is List
          ? items
              .whereType<Map<String, dynamic>>()
              .map(OrderLine.fromApi)
              .toList()
          : const [],
      photos: photos is List
          ? photos
              .whereType<Map<String, dynamic>>()
              .map((photo) => OrderPhoto(
                    url: _text(photo['url']) ?? '',
                    stage: stageFromApiOrNull(photo['stage']),
                  ))
              .where((photo) => photo.url.isNotEmpty)
              .toList()
          : const [],
      hasDetail: items is List,
    );
  }
}

String? _text(Object? value) {
  if (value == null) return null;
  final text = '$value'.trim();
  return text.isEmpty ? null : text;
}

/// The server marks its timestamps with a zone, so this is the phone's local time.
DateTime? _date(Object? value) => value is String && value.isNotEmpty
    ? DateTime.tryParse(value)?.toLocal()
    : null;
