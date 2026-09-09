import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../state/orders_controller.dart';
import '../utils/formatters.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_card.dart';
import '../widgets/status_chip.dart';
import 'order_detail_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrdersController>();
    final history = orders.history;

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: history.isEmpty
          ? const EmptyState(
              icon: Icons.history,
              title: 'Nothing here yet',
              message: 'Deliveries you complete will be listed here.',
            )
          : RefreshIndicator(
              onRefresh: orders.load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: history.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) =>
                    _HistoryTile(order: history[index]),
              ),
            ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final when = order.completedAt ?? order.placedAt;
    final delivered = order.status == OrderStatus.delivered;

    return SectionCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => OrderDetailScreen(orderId: order.id),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      order.code,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(status: order.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'To ${order.dropoff.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  '${shortDate(when)} · ${clockTime(when)} · ${distance(order.distanceKm)}',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Text(
            delivered ? money(order.riderEarnings) : '—',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: delivered ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
