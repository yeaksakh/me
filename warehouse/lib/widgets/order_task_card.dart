import 'package:flutter/material.dart';

import '../models/fulfilment_stage.dart';
import '../models/order.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'section_card.dart';
import 'stage_chip.dart';

/// One shipment in a tab.
///
/// Leads with the invoice number and how long it has been waiting, because in a
/// queue worked front to back those decide what a person picks up next -- and,
/// while it is `ordered`, whether anyone has taken it yet.
class OrderTaskCard extends StatelessWidget {
  const OrderTaskCard({
    super.key,
    required this.order,
    this.staffId,
    this.onTap,
  });

  final Order order;

  /// Who is signed in, so the card can say "Yours" rather than their own name.
  final String? staffId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final ordered = order.stage == FulfilmentStage.ordered;
    final partlyPacked = ordered && order.packedCount > 0 && !order.isFullyPacked;

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
          // phone, and a fact clipped off the edge is worse than one that moved
          // to a second line.
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _Fact(
                icon: Icons.inventory_2_outlined,
                text: plural(order.lineCount, 'item'),
              ),
              _Fact(
                icon: Icons.numbers,
                text: plural(order.totalQuantity.round(), 'unit'),
              ),
              _Fact(
                icon: Icons.schedule,
                text: waitingFor(order.placedAt),
              ),
              if (ordered && order.acceptedAt != null)
                _Fact(
                  icon: Icons.assignment_ind_outlined,
                  text: 'Accepted ${relativeTime(order.acceptedAt!)}',
                ),
            ],
          ),
          if (partlyPacked) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: order.packProgress,
                minHeight: 6,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(colors.forStage(order.stage)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${order.packedCount} of ${order.lineCount} packed',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (ordered && !order.isAccepted)
                _Tag(
                  icon: Icons.assignment_ind_outlined,
                  label: 'Not accepted',
                  color: colors.ordered,
                )
              else if (ordered && order.isAcceptedBy(staffId))
                _Tag(
                  icon: Icons.person,
                  label: 'Yours',
                  color: colors.checked,
                )
              else if (order.isAccepted)
                _Tag(
                  icon: Icons.person_outline,
                  label: 'With ${order.preparedBy!.name}',
                  color: scheme.onSurfaceVariant,
                ),
              if (order.isCashOnDelivery)
                _Tag(
                  icon: Icons.payments_outlined,
                  label: 'Collect cash',
                  color: colors.prepared,
                ),
              if (order.note.isNotEmpty)
                _Tag(
                  icon: Icons.sticky_note_2_outlined,
                  label: 'Has a note',
                  color: scheme.onSurfaceVariant,
                ),
            ],
          ),
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
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty-tab copy, phrased per status. A blank Ordered tab means the floor is
/// caught up, which is worth saying rather than showing a generic shrug.
({IconData icon, String title, String message}) emptyQueueCopy(
  FulfilmentStage stage,
) =>
    switch (stage) {
      FulfilmentStage.ordered => (
          icon: Icons.check_circle_outline,
          title: 'Nothing to pack',
          message: 'New orders land here. Accept one to start packing it.',
        ),
      FulfilmentStage.packed => (
          icon: Icons.fact_check_outlined,
          title: 'Nothing waiting for audit',
          message: 'Packed shipments wait here until a supervisor checks them.',
        ),
      FulfilmentStage.audited => (
          icon: Icons.local_shipping_outlined,
          title: 'Nothing waiting for a rider',
          message: 'Audited shipments sit here until the rider picks them up.',
        ),
      _ => (
          icon: Icons.inbox_outlined,
          title: 'Nothing here',
          message: 'No shipments at this status.',
        ),
    };
