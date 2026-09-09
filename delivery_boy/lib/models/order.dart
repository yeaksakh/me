import 'address.dart';

/// The lifecycle of a delivery, in the order a rider moves through it.
enum OrderStatus { pending, accepted, pickedUp, onTheWay, delivered, cancelled }

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
        OrderStatus.pending => 'New request',
        OrderStatus.accepted => 'Accepted',
        OrderStatus.pickedUp => 'Picked up',
        OrderStatus.onTheWay => 'On the way',
        OrderStatus.delivered => 'Delivered',
        OrderStatus.cancelled => 'Cancelled',
      };

  /// The call to action that moves the rider to the next step.
  String get actionLabel => switch (this) {
        OrderStatus.accepted => 'Confirm pickup',
        OrderStatus.pickedUp => 'Start delivery',
        OrderStatus.onTheWay => 'Mark delivered',
        _ => 'Done',
      };

  /// The next status, or null when the order has reached a terminal state.
  OrderStatus? get next => switch (this) {
        OrderStatus.pending => OrderStatus.accepted,
        OrderStatus.accepted => OrderStatus.pickedUp,
        OrderStatus.pickedUp => OrderStatus.onTheWay,
        OrderStatus.onTheWay => OrderStatus.delivered,
        OrderStatus.delivered || OrderStatus.cancelled => null,
      };

  bool get isActive =>
      this == OrderStatus.accepted ||
      this == OrderStatus.pickedUp ||
      this == OrderStatus.onTheWay;

  bool get isFinished =>
      this == OrderStatus.delivered || this == OrderStatus.cancelled;
}

enum PaymentMethod { cash, prepaid }

extension PaymentMethodX on PaymentMethod {
  String get label =>
      this == PaymentMethod.cash ? 'Cash on delivery' : 'Paid online';
}

class OrderItem {
  const OrderItem({required this.name, required this.quantity, required this.price});

  final String name;
  final int quantity;
  final double price;

  double get lineTotal => price * quantity;

  Map<String, dynamic> toJson() =>
      {'name': name, 'quantity': quantity, 'price': price};

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        name: json['name'] as String,
        quantity: json['quantity'] as int,
        price: (json['price'] as num).toDouble(),
      );
}

/// Reads an enum back by name, falling back when a stored value is unknown
/// (an app downgrade, or a hand-edited store).
T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

class Order {
  Order({
    required this.id,
    required this.code,
    required this.pickup,
    required this.dropoff,
    required this.items,
    required this.deliveryFee,
    required this.distanceKm,
    required this.etaMinutes,
    required this.paymentMethod,
    required this.placedAt,
    this.tip = 0,
    this.status = OrderStatus.pending,
    this.completedAt,
    this.cashCollected = false,
    this.deliveryNote,
  });

  final String id;
  final String code;
  final Address pickup;
  final Address dropoff;
  final List<OrderItem> items;
  final double deliveryFee;
  final double distanceKm;
  final int etaMinutes;
  final PaymentMethod paymentMethod;
  final DateTime placedAt;
  final double tip;

  OrderStatus status;
  DateTime? completedAt;

  /// Proof of delivery, captured when the rider closes the order out.
  bool cashCollected;
  String? deliveryNote;

  double get itemsTotal =>
      items.fold(0, (sum, item) => sum + item.lineTotal);

  /// What the rider collects at the door. Prepaid orders collect nothing.
  double get amountToCollect =>
      paymentMethod == PaymentMethod.cash ? itemsTotal + deliveryFee : 0;

  /// What the rider actually earns from this delivery.
  double get riderEarnings => deliveryFee + tip;

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'pickup': pickup.toJson(),
        'dropoff': dropoff.toJson(),
        'items': items.map((item) => item.toJson()).toList(),
        'deliveryFee': deliveryFee,
        'distanceKm': distanceKm,
        'etaMinutes': etaMinutes,
        'paymentMethod': paymentMethod.name,
        'placedAt': placedAt.toIso8601String(),
        'tip': tip,
        'status': status.name,
        'completedAt': completedAt?.toIso8601String(),
        'cashCollected': cashCollected,
        'deliveryNote': deliveryNote,
      };

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as String,
        code: json['code'] as String,
        pickup: Address.fromJson(json['pickup'] as Map<String, dynamic>),
        dropoff: Address.fromJson(json['dropoff'] as Map<String, dynamic>),
        items: (json['items'] as List<dynamic>)
            .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
            .toList(),
        deliveryFee: (json['deliveryFee'] as num).toDouble(),
        distanceKm: (json['distanceKm'] as num).toDouble(),
        etaMinutes: json['etaMinutes'] as int,
        paymentMethod: _enumByName(
          PaymentMethod.values,
          json['paymentMethod'],
          PaymentMethod.cash,
        ),
        placedAt: DateTime.parse(json['placedAt'] as String),
        tip: (json['tip'] as num?)?.toDouble() ?? 0,
        status: _enumByName(
          OrderStatus.values,
          json['status'],
          OrderStatus.pending,
        ),
        completedAt: json['completedAt'] == null
            ? null
            : DateTime.parse(json['completedAt'] as String),
        cashCollected: json['cashCollected'] as bool? ?? false,
        deliveryNote: json['deliveryNote'] as String?,
      );
}
