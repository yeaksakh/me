import 'package:flutter/material.dart';

import '../models/fulfilment_stage.dart';
import '../models/order.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'section_card.dart';
import 'stage_chip.dart';

/// One order in a queue.
///
/// Leads with the order code and how long it has been waiting, because in a
/// queue worked front-to-back those are the two things that decide what a person
/// picks up next.
class OrderTaskCard extends StatelessWidget {
  const OrderTaskCard({super.key, required this.order, this.onTap});

  final Order order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final progress = order.pickProgress;
    final partlyPicked = progress > 0 && progress < 1;

    return SectionCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.code,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              StageChip(stage: order.stage),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            order.customerName,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          // Wrap, not Row: three facts and their spacers overflow a 360px
          // phone, and a fact that has been clipped off the edge is worse than
          // one that moved to a second line.
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _Fact(
                icon: Icons.inventory_2_outlined,
                text: plural(order.lineCount, 'line'),
              ),
              _Fact(
                icon: Icons.numbers,
                text: plural(order.unitCount, 'unit'),
              ),
              _Fact(
                icon: Icons.schedule,
                text: waitingFor(order.placedAt),
              ),
            ],
          ),
          if (partlyPicked) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  colors.forStage(order.stage),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${order.pickedCount} of ${order.unitCount} picked',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
          if (order.isCashOnDelivery || order.staffNote != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (order.isCashOnDelivery)
                  _Tag(
                    icon: Icons.payments_outlined,
                    label: 'Collect cash',
                    color: colors.prepared,
                  ),
                if (order.staffNote != null)
                  _Tag(
                    icon: Icons.sticky_note_2_outlined,
                    label: 'Has a note',
                    color: scheme.onSurfaceVariant,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty-queue copy, phrased per stage. A blank "To prepare" tab means the floor
/// is caught up, which is worth saying rather than showing a generic shrug.
({IconData icon, String title, String message}) emptyQueueCopy(
  FulfilmentStage stage,
) =>
    switch (stage) {
      FulfilmentStage.ordered => (
          icon: Icons.check_circle_outline,
          title: 'Nothing to prepare',
          message: 'Every new order has been packed. New ones land here.',
        ),
      FulfilmentStage.prepared => (
          icon: Icons.fact_check_outlined,
          title: 'Nothing to check',
          message: 'Packed orders waiting for a second pair of eyes show here.',
        ),
      FulfilmentStage.checked => (
          icon: Icons.local_shipping_outlined,
          title: 'Nothing waiting for a driver',
          message: 'Checked orders sit here until a rider collects them.',
        ),
      _ => (
          icon: Icons.inbox_outlined,
          title: 'Nothing here',
          message: 'No orders at this stage.',
        ),
    };
