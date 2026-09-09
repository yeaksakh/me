import 'package:delivery_boy/data/local_store.dart';
import 'package:delivery_boy/data/order_repository.dart';
import 'package:delivery_boy/models/address.dart';
import 'package:delivery_boy/models/order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Order sampleOrder({
  String id = 'o-1',
  OrderStatus status = OrderStatus.pending,
}) {
  return Order(
    id: id,
    code: 'ORD-$id',
    pickup: const Address(
      label: 'Store',
      line1: '1 Main St',
      city: 'Town',
      contactPhone: '+1 555 0000',
    ),
    dropoff: const Address(
      label: 'Customer',
      line1: '2 Side St',
      city: 'Town',
      contactName: 'Dana',
      contactPhone: '+1 555 1111',
    ),
    items: const [
      OrderItem(name: 'Meal', quantity: 2, price: 5.5),
      OrderItem(name: 'Drink', quantity: 1, price: 2.25),
    ],
    deliveryFee: 2.4,
    tip: 0.6,
    distanceKm: 3.5,
    etaMinutes: 17,
    paymentMethod: PaymentMethod.cash,
    placedAt: DateTime(2026, 9, 9, 14, 30),
    status: status,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Order JSON', () {
    test('round-trips every field', () {
      final original = sampleOrder(status: OrderStatus.delivered)
        ..cashCollected = true
        ..deliveryNote = 'Left with reception'
        ..completedAt = DateTime(2026, 9, 9, 15, 5);

      final restored = Order.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.code, original.code);
      expect(restored.pickup.line1, original.pickup.line1);
      expect(restored.dropoff.contactName, 'Dana');
      expect(restored.items.length, 2);
      expect(restored.items.first.name, 'Meal');
      expect(restored.itemsTotal, original.itemsTotal);
      expect(restored.deliveryFee, original.deliveryFee);
      expect(restored.tip, original.tip);
      expect(restored.distanceKm, original.distanceKm);
      expect(restored.etaMinutes, original.etaMinutes);
      expect(restored.paymentMethod, PaymentMethod.cash);
      expect(restored.placedAt, original.placedAt);
      expect(restored.status, OrderStatus.delivered);
      expect(restored.completedAt, original.completedAt);
      expect(restored.cashCollected, isTrue);
      expect(restored.deliveryNote, 'Left with reception');
    });

    test('an unknown stored status falls back instead of throwing', () {
      final json = sampleOrder().toJson();
      json['status'] = 'teleported';
      json['paymentMethod'] = 'crypto';

      final restored = Order.fromJson(json);

      expect(restored.status, OrderStatus.pending);
      expect(restored.paymentMethod, PaymentMethod.cash);
    });
  });

  group('LocalStore', () {
    test('saves and reloads orders', () async {
      final store = LocalStore();
      await store.saveOrders([sampleOrder(id: 'a'), sampleOrder(id: 'b')]);

      final loaded = await store.loadOrders();

      expect(loaded, isNotNull);
      expect(loaded!.map((o) => o.id), ['a', 'b']);
    });

    test('returns null when nothing has been saved', () async {
      expect(await LocalStore().loadOrders(), isNull);
    });

    test('discards a corrupt payload rather than throwing', () async {
      SharedPreferences.setMockInitialValues({'flutter.orders_v1': '{not json'});

      expect(await LocalStore().loadOrders(), isNull);
    });

    test('round-trips the session flags', () async {
      final store = LocalStore();
      await store.saveSession(signedIn: true, online: false);

      final session = await store.loadSession();

      expect(session.signedIn, isTrue);
      expect(session.online, isFalse);
    });
  });

  group('OrderRepository persistence', () {
    test('an in-progress delivery survives a restart', () async {
      final store = LocalStore();
      final first = OrderRepository(
        initial: [sampleOrder(id: 'live')],
        store: store,
      )..latency = Duration.zero;

      await first.fetchOrders();
      await first.updateStatus('live', OrderStatus.pickedUp);

      // A fresh repository stands in for the next app launch.
      final second = OrderRepository(store: store)..latency = Duration.zero;
      final orders = await second.fetchOrders();

      expect(orders.map((o) => o.id), ['live']);
      expect(orders.single.status, OrderStatus.pickedUp);
    });

    test('proof of delivery is persisted', () async {
      final store = LocalStore();
      final first = OrderRepository(
        initial: [sampleOrder(id: 'x', status: OrderStatus.onTheWay)],
        store: store,
      )..latency = Duration.zero;

      await first.fetchOrders();
      await first.completeDelivery('x', cashCollected: true, note: 'At door');

      final second = OrderRepository(store: store)..latency = Duration.zero;
      final restored = (await second.fetchOrders()).single;

      expect(restored.status, OrderStatus.delivered);
      expect(restored.cashCollected, isTrue);
      expect(restored.deliveryNote, 'At door');
    });

    test('seed data is written on a first run', () async {
      final store = LocalStore();
      final repository = OrderRepository(store: store)..latency = Duration.zero;

      await repository.fetchOrders();

      expect(await store.loadOrders(), isNotNull);
    });
  });
}
