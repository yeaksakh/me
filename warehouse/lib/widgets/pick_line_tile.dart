import 'package:flutter/material.dart';

import '../models/order.dart';
import '../theme/app_theme.dart';
import 'motion.dart';

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
      child: AnimatedContainer(
        duration: kMotion,
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: highlighted
              ? tone.withAlpha(24)
              : line.packed
                  ? tone.withAlpha(12)
                  : colors.card,
          borderRadius: radius,
          border: Border.all(
            color: highlighted ? tone : scheme.outlineVariant.withAlpha(120),
            width: highlighted ? 2 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: onChanged == null ? null : () => onChanged(!line.packed),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The tick pops in: the one moment on this screen worth a
                  // flourish, because it is the moment the work happened.
                  Morph(
                    child: Icon(
                      line.packed
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      key: ValueKey(line.packed),
                      color: tone,
                      size: 26,
                    ),
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
                        // The shelf first and largest: it is read from across
                        // the aisle, before the name matters.
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: line.hasLocation
                                ? scheme.primary.withAlpha(22)
                                : scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.shelves,
                                size: 16,
                                color: line.hasLocation
                                    ? scheme.primary
                                    : scheme.outline,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  line.location ?? 'No rack location set',
                                  style: TextStyle(
                                    fontSize: line.hasLocation ? 15 : 12,
                                    fontWeight: line.hasLocation
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: line.hasLocation
                                        ? scheme.primary
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
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
      ),
    );
  }
}
