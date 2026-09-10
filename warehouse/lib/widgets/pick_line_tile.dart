import 'package:flutter/material.dart';

import '../models/order.dart';
import '../theme/app_theme.dart';

/// One item on a shipment, and whether it is in the box.
///
/// The shelf position is set large and first: a packer reads it from across the
/// aisle, and the product name only matters once they are standing at the shelf.
/// Tapping anywhere on the row ticks it, because this is used one-handed.
class PickLineTile extends StatelessWidget {
  const PickLineTile({
    super.key,
    required this.line,
    this.onPackedChanged,
    this.highlighted = false,
  });

  final OrderLine line;

  /// Null when the item cannot be ticked here -- the shipment is someone else's,
  /// or packing is over -- which draws the row read-only.
  final ValueChanged<bool>? onPackedChanged;

  /// True just after a scan landed here, so the eye can find the row again.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final onChanged = onPackedChanged;
    final tone = line.packed ? colors.inStock : scheme.outline;
    final radius = BorderRadius.circular(16);

    return Padding(
      // The items inside a bundle sit under it, so the box's contents read as
      // the bundle and its parts rather than as unrelated lines.
      padding: EdgeInsets.only(left: line.isBundleItem ? 24 : 0),
      child: Material(
        color: highlighted ? tone.withAlpha(24) : colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: highlighted ? tone : scheme.outlineVariant.withAlpha(120),
            width: highlighted ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onChanged == null ? null : () => onChanged(!line.packed),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  line.packed ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: tone,
                  size: 26,
                ),
                const SizedBox(width: 12),
                if (line.imageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      line.imageUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const SizedBox(width: 48, height: 48),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (line.location != null)
                        Text(
                          line.location!,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: scheme.primary,
                          ),
                        ),
                      Text(
                        line.displayName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (line.sku.isNotEmpty) line.sku,
                          '× ${line.quantityLabel}',
                        ].join('  ·  '),
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (line.packed && line.packedBy != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Packed by ${line.packedBy!.name}',
                          style: TextStyle(fontSize: 12, color: tone),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
