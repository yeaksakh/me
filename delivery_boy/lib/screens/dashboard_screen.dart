import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../state/orders_controller.dart';
import '../state/session_controller.dart';
import '../utils/formatters.dart';
import '../widgets/empty_state.dart';
import '../widgets/order_card.dart';
import '../widgets/section_card.dart';
import '../widgets/stat_tile.dart';
import 'active_delivery_screen.dart';
import 'order_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final orders = context.watch<OrdersController>();
    final active = orders.activeOrder;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hi, ${session.driver?.name.split(' ').first ?? 'rider'}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            Text(
              session.isOnline ? 'You are online' : 'You are offline',
              style: TextStyle(
                fontSize: 12,
                color: session.isOnline ? Colors.green.shade700 : Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          Switch(
            value: session.isOnline,
            onChanged: session.setOnline,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: orders.load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Deliveries today',
                    value: '${orders.deliveriesToday}',
                    icon: Icons.check_circle_outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatTile(
                    label: 'Earned today',
                    value: money(orders.earningsToday),
                    icon: Icons.payments_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatTile(
                    label: 'Distance',
                    value: distance(orders.distanceToday),
                    icon: Icons.route_outlined,
                  ),
                ),
              ],
            ),
            if (active != null) ...[
              const SizedBox(height: 20),
              const _SectionHeader('Current delivery'),
              const SizedBox(height: 10),
              _ActiveBanner(order: active),
            ],
            const SizedBox(height: 20),
            const _SectionHeader('New requests'),
            const SizedBox(height: 10),
            ..._buildRequests(context, orders, session),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRequests(
    BuildContext context,
    OrdersController orders,
    SessionController session,
  ) {
    if (orders.loading && orders.all.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (!session.isOnline) {
      return const [
        SizedBox(
          height: 260,
          child: EmptyState(
            icon: Icons.pause_circle_outline,
            title: 'You are offline',
            message: 'Turn the switch on to start receiving order requests.',
          ),
        ),
      ];
    }

    final available = orders.available;
    if (available.isEmpty) {
      return const [
        SizedBox(
          height: 260,
          child: EmptyState(
            icon: Icons.inbox_outlined,
            title: 'No new requests',
            message: 'New orders near you will appear here automatically.',
          ),
        ),
      ];
    }

    return [
      for (final order in available) ...[
        OrderCard(
          order: order,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => OrderDetailScreen(orderId: order.id),
            ),
          ),
          onAccept: () => _accept(context, orders, order),
          onDecline: () => orders.decline(order.id),
        ),
        const SizedBox(height: 12),
      ],
    ];
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
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => ActiveDeliveryScreen(orderId: order.id),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      );
}

class _ActiveBanner extends StatelessWidget {
  const _ActiveBanner({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ActiveDeliveryScreen(orderId: order.id),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: scheme.primary,
            child: const Icon(Icons.local_shipping, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.code,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${order.status.label} · to ${order.dropoff.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
