import 'package:delivery_boy/data/order_repository.dart';
import 'package:delivery_boy/models/address.dart';
import 'package:delivery_boy/models/order.dart';
import 'package:delivery_boy/state/orders_controller.dart';
import 'package:flutter_test/flutter_test.dart';

Order buildOrder({
  required String id,
  OrderStatus status = OrderStatus.pending,
  double deliveryFee = 2.0,
  double tip = 0,
  PaymentMethod payment = PaymentMethod.cash,
  DateTime? completedAt,
}) {
  return Order(
    id: id,
    code: 'ORD-$id',
    pickup: const Address(label: 'Store', line1: '1 Main St', city: 'Town'),
    dropoff: const Address(label: 'Customer', line1: '2 Side St', city: 'Town'),
    items: const [OrderItem(name: 'Meal', quantity: 2, price: 5.0)],
    deliveryFee: deliveryFee,
    tip: tip,
    distanceKm: 3.0,
    etaMinutes: 15,
    paymentMethod: payment,
    placedAt: DateTime.now(),
    status: status,
    completedAt: completedAt,
  );
}

OrdersController controllerWith(List<Order> orders) {
  final repository = OrderRepository(initial: orders)..latency = Duration.zero;
  return OrdersController(repository);
}

void main() {
  group('Order maths', () {
    test('items total multiplies quantity by price', () {
      expect(buildOrder(id: '1').itemsTotal, 10.0);
    });

    test('cash orders collect items plus fee', () {
      final order = buildOrder(id: '1', deliveryFee: 2.5);
      expect(order.amountToCollect, 12.5);
    });

    test('prepaid orders collect nothing', () {
      final order = buildOrder(id: '1', payment: PaymentMethod.prepaid);
      expect(order.amountToCollect, 0);
    });

    test('rider earnings are fee plus tip', () {
      final order = buildOrder(id: '1', deliveryFee: 2.0, tip: 1.5);
      expect(order.riderEarnings, 3.5);
    });
  });

  group('Status flow', () {
    test('advances pending through to delivered', () {
      expect(OrderStatus.pending.next, OrderStatus.accepted);
      expect(OrderStatus.accepted.next, OrderStatus.pickedUp);
      expect(OrderStatus.pickedUp.next, OrderStatus.onTheWay);
      expect(OrderStatus.onTheWay.next, OrderStatus.delivered);
    });

    test('terminal states do not advance', () {
      expect(OrderStatus.delivered.next, isNull);
      expect(OrderStatus.cancelled.next, isNull);
    });
  });

  group('OrdersController', () {
    test('load exposes pending orders as available', () async {
      final controller = controllerWith([
        buildOrder(id: '1'),
        buildOrder(id: '2', status: OrderStatus.delivered),
      ]);
      await controller.load();

      expect(controller.available.map((o) => o.id), ['1']);
      expect(controller.loading, isFalse);
    });

    test('accepting an order makes it the active delivery', () async {
      final controller = controllerWith([buildOrder(id: '1')]);
      await controller.load();

      expect(await controller.accept('1'), isTrue);
      expect(controller.activeOrder?.id, '1');
      expect(controller.available, isEmpty);
    });

    test('a second order cannot be accepted while one is active', () async {
      final controller = controllerWith([
        buildOrder(id: '1'),
        buildOrder(id: '2'),
      ]);
      await controller.load();
      await controller.accept('1');

      expect(await controller.accept('2'), isFalse);
      expect(controller.error, isNotNull);
      expect(controller.activeOrder?.id, '1');
    });

    test('advance walks the delivery to delivered and clears active', () async {
      final controller = controllerWith([buildOrder(id: '1')]);
      await controller.load();
      await controller.accept('1');

      await controller.advance('1');
      expect(controller.orderById('1')!.status, OrderStatus.pickedUp);
      await controller.advance('1');
      expect(controller.orderById('1')!.status, OrderStatus.onTheWay);
      await controller.advance('1');

      expect(controller.orderById('1')!.status, OrderStatus.delivered);
      expect(controller.activeOrder, isNull);
      expect(controller.orderById('1')!.completedAt, isNotNull);
    });

    test('declining removes the order from the available feed', () async {
      final controller = controllerWith([buildOrder(id: '1')]);
      await controller.load();

      expect(await controller.decline('1'), isTrue);
      expect(controller.available, isEmpty);
      expect(controller.orderById('1')!.status, OrderStatus.cancelled);
    });

    test('today totals count only deliveries completed today', () async {
      final controller = controllerWith([
        buildOrder(
          id: '1',
          status: OrderStatus.delivered,
          deliveryFee: 2.0,
          tip: 1.0,
          completedAt: DateTime.now(),
        ),
        buildOrder(
          id: '2',
          status: OrderStatus.delivered,
          deliveryFee: 5.0,
          completedAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ]);
      await controller.load();

      expect(controller.deliveriesToday, 1);
      expect(controller.earningsToday, 3.0);
      expect(controller.earningsAllTime, 8.0);
    });

    test('history is newest first and excludes live orders', () async {
      final now = DateTime.now();
      final controller = controllerWith([
        buildOrder(
          id: 'old',
          status: OrderStatus.delivered,
          completedAt: now.subtract(const Duration(hours: 5)),
        ),
        buildOrder(
          id: 'new',
          status: OrderStatus.delivered,
          completedAt: now,
        ),
        buildOrder(id: 'live'),
      ]);
      await controller.load();

      expect(controller.history.map((o) => o.id), ['new', 'old']);
    });
  });
}
