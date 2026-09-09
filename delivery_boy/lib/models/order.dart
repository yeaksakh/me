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

  double get itemsTotal =>
      items.fold(0, (sum, item) => sum + item.lineTotal);

  /// What the rider collects at the door. Prepaid orders collect nothing.
  double get amountToCollect =>
      paymentMethod == PaymentMethod.cash ? itemsTotal + deliveryFee : 0;

  /// What the rider actually earns from this delivery.
  double get riderEarnings => deliveryFee + tip;

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
}
