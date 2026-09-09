import 'package:flutter/foundation.dart';

import '../data/order_repository.dart';
import '../models/order.dart';
import '../utils/formatters.dart';

/// Owns the rider's order list and the rules for moving a delivery forward.
class OrdersController extends ChangeNotifier {
  OrdersController(this._repository);

  final OrderRepository _repository;

  List<Order> _orders = const [];
  bool _loading = false;
  String? _error;

  bool get loading => _loading;
  String? get error => _error;
  List<Order> get all => List<Order>.unmodifiable(_orders);

  /// Incoming requests the rider has not answered yet, newest first.
  List<Order> get available => _orders
      .where((o) => o.status == OrderStatus.pending)
      .toList()
    ..sort((a, b) => b.placedAt.compareTo(a.placedAt));

  /// A rider carries one delivery at a time.
  Order? get activeOrder {
    for (final order in _orders) {
      if (order.status.isActive) return order;
    }
    return null;
  }

  bool get hasActiveOrder => activeOrder != null;

  /// Finished work, most recent first.
  List<Order> get history {
    final done = _orders.where((o) => o.status.isFinished).toList();
    done.sort((a, b) {
      final aTime = a.completedAt ?? a.placedAt;
      final bTime = b.completedAt ?? b.placedAt;
      return bTime.compareTo(aTime);
    });
    return done;
  }

  List<Order> get _deliveredToday {
    final now = DateTime.now();
    return _orders
        .where((o) =>
            o.status == OrderStatus.delivered &&
            o.completedAt != null &&
            isSameDay(o.completedAt!, now))
        .toList();
  }

  int get deliveriesToday => _deliveredToday.length;

  double get earningsToday =>
      _deliveredToday.fold(0, (sum, o) => sum + o.riderEarnings);

  double get distanceToday =>
      _deliveredToday.fold(0, (sum, o) => sum + o.distanceKm);

  double get earningsAllTime => _orders
      .where((o) => o.status == OrderStatus.delivered)
      .fold(0, (sum, o) => sum + o.riderEarnings);

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _orders = await _repository.fetchOrders();
    } catch (e) {
      _error = 'Could not load orders. Pull to retry.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Take a pending order. Refused while another delivery is in progress.
  Future<bool> accept(String orderId) async {
    if (hasActiveOrder) {
      _error = 'Finish your current delivery first.';
      notifyListeners();
      return false;
    }
    return _moveTo(orderId, OrderStatus.accepted);
  }

  Future<bool> decline(String orderId) => _moveTo(orderId, OrderStatus.cancelled);

  Future<bool> cancelActive() async {
    final order = activeOrder;
    if (order == null) return false;
    return _moveTo(order.id, OrderStatus.cancelled);
  }

  /// Step the active order to the next stage of the delivery.
  ///
  /// Stops short of `delivered`: closing an order out requires proof, so the
  /// last step goes through [completeDelivery] instead.
  Future<bool> advance(String orderId) async {
    final order = _findOrNull(orderId);
    final next = order?.status.next;
    if (order == null || next == null) return false;
    if (next == OrderStatus.delivered) {
      _error = 'Confirm the drop-off to close this order.';
      notifyListeners();
      return false;
    }
    return _moveTo(orderId, next);
  }

  /// Close out a delivery. Cash orders cannot be closed until the rider
  /// confirms they took the money.
  Future<bool> completeDelivery(
    String orderId, {
    required bool cashCollected,
    String? note,
  }) async {
    final order = _findOrNull(orderId);
    if (order == null) return false;
    if (order.paymentMethod == PaymentMethod.cash && !cashCollected) {
      _error = 'Confirm you collected the cash first.';
      notifyListeners();
      return false;
    }
    _error = null;
    try {
      await _repository.completeDelivery(
        orderId,
        cashCollected: cashCollected,
        note: note,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'That delivery could not be closed.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> _moveTo(String orderId, OrderStatus status) async {
    _error = null;
    try {
      await _repository.updateStatus(orderId, status);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'That order could not be updated.';
      notifyListeners();
      return false;
    }
  }

  Order? _findOrNull(String orderId) {
    for (final order in _orders) {
      if (order.id == orderId) return order;
    }
    return null;
  }

  Order? orderById(String orderId) => _findOrNull(orderId);

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }
}
