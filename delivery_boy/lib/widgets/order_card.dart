import 'package:flutter/material.dart';

import '../models/order.dart';
import '../utils/formatters.dart';
import 'section_card.dart';
import 'status_chip.dart';

/// One order in a list: route, distance, payout, and optional accept/decline.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    this.onTap,
    this.onAccept,
    this.onDecline,
  });

  final Order order;
  final VoidCallback? onTap;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showActions = onAccept != null || onDecline != null;

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
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              StatusChip(status: order.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${relativeTime(order.placedAt)} · ${order.itemCount} items',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          _RoutePoint(
            icon: Icons.storefront_outlined,
            color: scheme.primary,
            title: order.pickup.label,
            subtitle: order.pickup.full,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: SizedBox(
              height: 18,
              child: VerticalDivider(
                width: 2,
                thickness: 2,
                color: scheme.outlineVariant,
              ),
            ),
          ),
          _RoutePoint(
            icon: Icons.location_on_outlined,
            color: scheme.error,
            title: order.dropoff.label,
            subtitle: order.dropoff.full,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Meta(icon: Icons.route_outlined, text: distance(order.distanceKm)),
              const SizedBox(width: 16),
              _Meta(icon: Icons.schedule, text: '${order.etaMinutes} min'),
              const Spacer(),
              Text(
                money(order.riderEarnings),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          if (showActions) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (onDecline != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDecline,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                if (onDecline != null && onAccept != null)
                  const SizedBox(width: 12),
                if (onAccept != null)
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: onAccept,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                      child: const Text('Accept order'),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RoutePoint extends StatelessWidget {
  const _RoutePoint({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
      ],
    );
  }
}
