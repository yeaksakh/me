import '../models/address.dart';
import '../models/driver.dart';
import '../models/order.dart';

/// Seed content so the app is fully explorable without a backend.
class MockData {
  static final Driver driver = Driver(
    id: 'rider-01',
    name: 'Yeak Sakh',
    phone: '+1 555 0142',
    vehicle: 'Honda Vision · 88H-421.09',
    rating: 4.8,
    joinedOn: DateTime(2024, 3, 14),
  );

  static List<Order> seedOrders() {
    final now = DateTime.now();
    return [
      Order(
        id: 'o-1042',
        code: 'ORD-1042',
        pickup: const Address(
          label: 'Spice Garden',
          line1: '18 Norodom Blvd',
          city: 'Phnom Penh',
          contactName: 'Spice Garden counter',
          contactPhone: '+1 555 0311',
        ),
        dropoff: const Address(
          label: 'Sophea Chan',
          line1: 'Apt 4B, 210 Street 271',
          city: 'Phnom Penh',
          contactName: 'Sophea Chan',
          contactPhone: '+1 555 0199',
        ),
        items: const [
          OrderItem(name: 'Chicken amok', quantity: 2, price: 6.50),
          OrderItem(name: 'Jasmine rice', quantity: 2, price: 1.25),
          OrderItem(name: 'Iced coffee', quantity: 1, price: 2.75),
        ],
        deliveryFee: 2.50,
        tip: 1.00,
        distanceKm: 3.2,
        etaMinutes: 18,
        paymentMethod: PaymentMethod.cash,
        placedAt: now.subtract(const Duration(minutes: 4)),
      ),
      Order(
        id: 'o-1043',
        code: 'ORD-1043',
        pickup: const Address(
          label: 'Fresh Mart',
          line1: '77 Street 154',
          city: 'Phnom Penh',
          contactPhone: '+1 555 0388',
        ),
        dropoff: const Address(
          label: 'Daniel Rou',
          line1: 'Villa 12, Koh Pich',
          city: 'Phnom Penh',
          contactName: 'Daniel Rou',
          contactPhone: '+1 555 0244',
        ),
        items: const [
          OrderItem(name: 'Grocery bundle', quantity: 1, price: 24.00),
          OrderItem(name: 'Drinking water 5L', quantity: 2, price: 1.50),
        ],
        deliveryFee: 3.20,
        distanceKm: 5.6,
        etaMinutes: 26,
        paymentMethod: PaymentMethod.prepaid,
        placedAt: now.subtract(const Duration(minutes: 9)),
      ),
      Order(
        id: 'o-1044',
        code: 'ORD-1044',
        pickup: const Address(
          label: 'Bakery No.5',
          line1: '5 Street 240',
          city: 'Phnom Penh',
          contactPhone: '+1 555 0455',
        ),
        dropoff: const Address(
          label: 'Mony Sok',
          line1: 'Office 3F, Vattanac Tower',
          city: 'Phnom Penh',
          contactName: 'Mony Sok',
          contactPhone: '+1 555 0277',
        ),
        items: const [
          OrderItem(name: 'Croissant', quantity: 6, price: 1.80),
          OrderItem(name: 'Flat white', quantity: 3, price: 3.00),
        ],
        deliveryFee: 2.00,
        tip: 0.50,
        distanceKm: 1.9,
        etaMinutes: 12,
        paymentMethod: PaymentMethod.cash,
        placedAt: now.subtract(const Duration(minutes: 12)),
      ),
      // Already-finished runs, so History and Earnings have something to show.
      Order(
        id: 'o-1038',
        code: 'ORD-1038',
        pickup: const Address(
          label: 'Noodle House',
          line1: '44 Street 63',
          city: 'Phnom Penh',
        ),
        dropoff: const Address(
          label: 'Lina Prak',
          line1: '9 Street 310',
          city: 'Phnom Penh',
          contactName: 'Lina Prak',
        ),
        items: const [OrderItem(name: 'Beef noodle soup', quantity: 2, price: 5.00)],
        deliveryFee: 2.40,
        tip: 0.60,
        distanceKm: 2.8,
        etaMinutes: 15,
        paymentMethod: PaymentMethod.prepaid,
        placedAt: now.subtract(const Duration(hours: 2, minutes: 20)),
        status: OrderStatus.delivered,
        completedAt: now.subtract(const Duration(hours: 2)),
      ),
      Order(
        id: 'o-1035',
        code: 'ORD-1035',
        pickup: const Address(
          label: 'Green Pharmacy',
          line1: '120 Monivong Blvd',
          city: 'Phnom Penh',
        ),
        dropoff: const Address(
          label: 'Ratana Kim',
          line1: '31 Street 105',
          city: 'Phnom Penh',
          contactName: 'Ratana Kim',
        ),
        items: const [OrderItem(name: 'Pharmacy parcel', quantity: 1, price: 12.40)],
        deliveryFee: 2.80,
        distanceKm: 4.1,
        etaMinutes: 20,
        paymentMethod: PaymentMethod.cash,
        placedAt: now.subtract(const Duration(hours: 4, minutes: 10)),
        status: OrderStatus.delivered,
        completedAt: now.subtract(const Duration(hours: 3, minutes: 45)),
      ),
      Order(
        id: 'o-1031',
        code: 'ORD-1031',
        pickup: const Address(
          label: 'Burger Lab',
          line1: '2 Street 51',
          city: 'Phnom Penh',
        ),
        dropoff: const Address(
          label: 'Visal Ny',
          line1: '88 Street 174',
          city: 'Phnom Penh',
          contactName: 'Visal Ny',
        ),
        items: const [OrderItem(name: 'Double cheeseburger', quantity: 1, price: 7.50)],
        deliveryFee: 2.20,
        distanceKm: 3.0,
        etaMinutes: 16,
        paymentMethod: PaymentMethod.prepaid,
        placedAt: now.subtract(const Duration(days: 1, hours: 3)),
        status: OrderStatus.cancelled,
        completedAt: now.subtract(const Duration(days: 1, hours: 2, minutes: 50)),
      ),
    ];
  }
}
