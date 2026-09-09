import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../state/orders_controller.dart';
import '../utils/formatters.dart';
import '../widgets/section_card.dart';
import '../widgets/status_chip.dart';
import 'active_delivery_screen.dart';

/// Read-only look at an order before the rider commits to it.
class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrdersController>();
    final order = orders.orderById(orderId);

    if (order == null) {
      return const Scaffold(
        body: Center(child: Text('This order is no longer available.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(order.code)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SectionCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Placed ${relativeTime(order.placedAt)}'),
                      const SizedBox(height: 4),
                      Text(
                        '${distance(order.distanceKm)} · about ${order.etaMinutes} min',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                StatusChip(status: order.status),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OrderRouteCard(order: order),
          const SizedBox(height: 12),
          OrderItemsCard(order: order),
          const SizedBox(height: 12),
          OrderPayoutCard(order: order),
          if (order.status == OrderStatus.delivered) ...[
            const SizedBox(height: 12),
            DeliveryProofCard(order: order),
          ],
          if (order.status == OrderStatus.pending) ...[
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _accept(context, orders, order),
              child: const Text('Accept order'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                orders.decline(order.id);
                Navigator.of(context).pop();
              },
              child: const Text('Decline'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _accept(
    BuildContext context,
    OrdersController orders,
    Order order,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final accepted = await orders.accept(order.id);
    if (!accepted) {
      messenger.showSnackBar(
        SnackBar(content: Text(orders.error ?? 'Could not accept that order.')),
      );
      orders.clearError();
      return;
    }
    navigator.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ActiveDeliveryScreen(orderId: order.id),
      ),
    );
  }
}

/// Pickup and drop-off, with the contact for each end of the trip.
class OrderRouteCard extends StatelessWidget {
  const OrderRouteCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('Route'),
          const SizedBox(height: 12),
          _Stop(
            icon: Icons.storefront_outlined,
            heading: 'Pick up',
            name: order.pickup.label,
            address: order.pickup.full,
            phone: order.pickup.contactPhone,
          ),
          const Divider(height: 28),
          _Stop(
            icon: Icons.location_on_outlined,
            heading: 'Drop off',
            name: order.dropoff.contactName ?? order.dropoff.label,
            address: order.dropoff.full,
            phone: order.dropoff.contactPhone,
          ),
        ],
      ),
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({
    required this.icon,
    required this.heading,
    required this.name,
    required this.address,
    this.phone,
  });

  final IconData icon;
  final String heading;
  final String name;
  final String address;
  final String? phone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: scheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                heading.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(address, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
        if (phone != null)
          IconButton(
            tooltip: 'Call $phone',
            icon: const Icon(Icons.phone),
            color: scheme.primary,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Calling $phone')),
              );
            },
          ),
      ],
    );
  }
}

class OrderItemsCard extends StatelessWidget {
  const OrderItemsCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('Items'),
          const SizedBox(height: 8),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${item.quantity}x',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(child: Text(item.name)),
                  Text(money(item.lineTotal)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class OrderPayoutCard extends StatelessWidget {
  const OrderPayoutCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('Payment'),
          const SizedBox(height: 8),
          _Line(label: 'Items total', value: money(order.itemsTotal)),
          _Line(label: 'Delivery fee', value: money(order.deliveryFee)),
          if (order.tip > 0) _Line(label: 'Tip', value: money(order.tip)),
          const Divider(height: 22),
          _Line(
            label: order.paymentMethod.label,
            value: order.amountToCollect > 0
                ? 'Collect ${money(order.amountToCollect)}'
                : 'Nothing to collect',
            emphasise: true,
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.savings_outlined, color: scheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text('You earn'),
                const Spacer(),
                Text(
                  money(order.riderEarnings),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What the rider recorded at the door. Only shown once delivered.
class DeliveryProofCard extends StatelessWidget {
  const DeliveryProofCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('Drop-off'),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                order.cashCollected
                    ? Icons.check_circle
                    : Icons.check_circle_outline,
                size: 20,
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.cashCollected
                      ? 'Collected ${money(order.amountToCollect)} in cash'
                      : 'Nothing to collect — paid online',
                ),
              ),
            ],
          ),
          if (order.completedAt != null) ...[
            const SizedBox(height: 6),
            Text(
              'Completed ${shortDate(order.completedAt!)} at '
              '${clockTime(order.completedAt!)}',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
          if (order.deliveryNote != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(order.deliveryNote!),
            ),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.emphasise = false,
  });

  final String label;
  final String value;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: emphasise ? FontWeight.w700 : FontWeight.w400,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      );
}
