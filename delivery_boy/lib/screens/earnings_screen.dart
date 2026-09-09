import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../state/orders_controller.dart';
import '../utils/formatters.dart';
import '../widgets/section_card.dart';
import '../widgets/stat_tile.dart';

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrdersController>();
    final scheme = Theme.of(context).colorScheme;
    final delivered = orders.all
        .where((o) => o.status == OrderStatus.delivered)
        .toList()
      ..sort((a, b) => (b.completedAt ?? b.placedAt)
          .compareTo(a.completedAt ?? a.placedAt));

    final fees = delivered.fold<double>(0, (sum, o) => sum + o.deliveryFee);
    final tips = delivered.fold<double>(0, (sum, o) => sum + o.tip);

    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SectionCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Text(
                  money(orders.earningsToday),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${orders.deliveriesToday} deliveries · ${distance(orders.distanceToday)}',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Delivery fees',
                  value: money(fees),
                  icon: Icons.local_shipping_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  label: 'Tips',
                  value: money(tips),
                  icon: Icons.volunteer_activism_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  label: 'All time',
                  value: money(orders.earningsAllTime),
                  icon: Icons.trending_up,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Payout breakdown',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (delivered.isEmpty)
            SectionCard(
              child: Text(
                'Complete a delivery to see your payouts here.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            )
          else
            SectionCard(
              child: Column(
                children: [
                  for (var i = 0; i < delivered.length; i++) ...[
                    if (i > 0) const Divider(height: 20),
                    _PayoutRow(order: delivered[i]),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PayoutRow extends StatelessWidget {
  const _PayoutRow({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final when = order.completedAt ?? order.placedAt;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.code,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${shortDate(when)} · fee ${money(order.deliveryFee)}'
                '${order.tip > 0 ? ' · tip ${money(order.tip)}' : ''}',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Text(
          money(order.riderEarnings),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
