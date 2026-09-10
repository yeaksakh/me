import 'package:flutter/material.dart';

import '../models/order.dart';
import '../theme/app_theme.dart';
import 'qty_stepper.dart';

/// One line of an order while it is being picked.
///
/// The bin location is set large and first: a picker reads it from across the
/// aisle, and the product name only matters once they are standing at the shelf.
class PickLineTile extends StatelessWidget {
  const PickLineTile({
    super.key,
    required this.line,
    required this.onPickedChanged,
    this.enabled = true,
    this.highlighted = false,
  });

  final OrderLine line;
  final ValueChanged<int> onPickedChanged;

  /// False once the order has moved past picking, so the numbers are frozen.
  final bool enabled;

  /// True just after a scan landed here, so the eye can find the row again.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    final tone = line.isComplete
        ? colors.inStock
        : line.isShort
            ? colors.lowStock
            : scheme.outline;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlighted ? tone.withAlpha(24) : colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted ? tone : scheme.outlineVariant.withAlpha(120),
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                line.isComplete
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: tone,
                size: 22,
              ),
              const SizedBox(width: 10),
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
                      line.sku,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${line.picked} / ${line.quantity}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: tone,
                  ),
                ),
              ),
              if (enabled)
                QtyStepper(
                  value: line.picked,
                  max: line.quantity,
                  onChanged: onPickedChanged,
                  onTapValue: () => _promptQuantity(context),
                )
              else
                Text(
                  line.isComplete ? 'Complete' : 'Short ${line.remaining}',
                  style: TextStyle(color: tone, fontWeight: FontWeight.w600),
                ),
            ],
          ),
          if (enabled && !line.isComplete) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => onPickedChanged(line.quantity),
              icon: const Icon(Icons.done_all, size: 18),
              label: Text('Take all ${line.quantity}'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _promptQuantity(BuildContext context) async {
    final controller = TextEditingController(text: '${line.picked}');
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );

    final entered = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(line.displayName),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Picked',
            helperText: 'Ordered: ${line.quantity}',
          ),
          onSubmitted: (value) =>
              Navigator.of(dialogContext).pop(int.tryParse(value)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext)
                .pop(int.tryParse(controller.text)),
            child: const Text('Set'),
          ),
        ],
      ),
    );

    if (entered != null) onPickedChanged(entered.clamp(0, line.quantity));
  }
}
