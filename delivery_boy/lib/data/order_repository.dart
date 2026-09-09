import '../models/order.dart';
import 'mock_data.dart';

/// Stands in for the network layer. Swap this class for real HTTP calls and
/// nothing above it has to change.
class OrderRepository {
  OrderRepository({List<Order>? initial})
      : _orders = initial ?? MockData.seedOrders();

  final List<Order> _orders;

  /// Simulated latency, so loading states are exercised in the UI.
  Duration latency = const Duration(milliseconds: 450);

  Future<List<Order>> fetchOrders() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return List<Order>.unmodifiable(_orders);
  }

  Future<Order> updateStatus(String orderId, OrderStatus status) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final order = _orders.firstWhere(
      (o) => o.id == orderId,
      orElse: () => throw StateError('No order with id $orderId'),
    );
    order.status = status;
    if (status.isFinished) order.completedAt = DateTime.now();
    return order;
  }
}
