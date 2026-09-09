import '../models/order.dart';
import 'local_store.dart';
import 'mock_data.dart';

/// Stands in for the network layer. Swap this class for real HTTP calls and
/// nothing above it has to change.
class OrderRepository {
  OrderRepository({List<Order>? initial, LocalStore? store})
      : _orders = initial ?? MockData.seedOrders(),
        _store = store;

  final List<Order> _orders;

  /// Optional. Without a store the repository is purely in-memory, which is
  /// what the tests use.
  final LocalStore? _store;
  bool _hydrated = false;

  /// Simulated latency, so loading states are exercised in the UI.
  Duration latency = const Duration(milliseconds: 450);

  Future<List<Order>> fetchOrders() async {
    await _hydrate();
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return List<Order>.unmodifiable(_orders);
  }

  /// Replaces the seed data with whatever was saved last run, once per session.
  Future<void> _hydrate() async {
    final store = _store;
    if (_hydrated || store == null) return;
    _hydrated = true;
    final saved = await store.loadOrders();
    if (saved != null && saved.isNotEmpty) {
      _orders
        ..clear()
        ..addAll(saved);
    } else {
      await store.saveOrders(_orders);
    }
  }

  Future<void> _persist() async => _store?.saveOrders(_orders);

  /// Close out a delivery, recording what the rider collected and saw.
  Future<Order> completeDelivery(
    String orderId, {
    required bool cashCollected,
    String? note,
  }) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final order = _find(orderId);
    order.cashCollected = cashCollected;
    final trimmed = note?.trim();
    order.deliveryNote =
        (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    order.status = OrderStatus.delivered;
    order.completedAt = DateTime.now();
    await _persist();
    return order;
  }

  Future<Order> updateStatus(String orderId, OrderStatus status) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final order = _find(orderId);
    order.status = status;
    if (status.isFinished) order.completedAt = DateTime.now();
    await _persist();
    return order;
  }

  Order _find(String orderId) => _orders.firstWhere(
        (o) => o.id == orderId,
        orElse: () => throw StateError('No order with id $orderId'),
      );
}
