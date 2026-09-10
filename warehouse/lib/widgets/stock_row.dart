import 'package:flutter/material.dart';

import '../models/stock_item.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'section_card.dart';

/// One catalogue row.
///
/// Shows sellable stock rather than on-hand as the headline number: on-hand
/// flatters, and "we have 12" when 12 are already promised to orders is how a
/// shop oversells.
class StockRow extends StatelessWidget {
  const StockRow({super.key, required this.item, this.onTap});

  final StockItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    final tone = item.isOutOfStock
        ? colors.outOfStock
        : item.isLow
            ? colors.lowStock
            : colors.inStock;

    return SectionCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      item.sku,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (item.location != null) ...[
                      Text(
                        '  ·  ',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      Text(
                        item.location!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
                if (item.reserved > 0) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${item.onHand} on hand · ${item.reserved} reserved',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.available}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: tone,
                ),
              ),
              Text(
                item.isOutOfStock
                    ? 'out'
                    : item.isLow
                        ? 'low'
                        : 'free',
                style: TextStyle(fontSize: 11, color: tone),
              ),
              if (item.countedAt != null)
                Text(
                  shortDate(item.countedAt!),
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
