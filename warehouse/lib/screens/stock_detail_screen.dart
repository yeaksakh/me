import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/stock_item.dart';
import '../models/staff.dart';
import '../state/session_controller.dart';
import '../state/stock_controller.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/qty_stepper.dart';
import '../widgets/section_card.dart';

/// One product: where it lives, what is on the shelf, and a way to correct it.
///
/// Adjustments are entered as a delta with a reason rather than by typing a new
/// on-hand. "Two were smashed" is what happened; "on hand is now 49" is a
/// conclusion, and only one of those is worth keeping in a ledger.
class StockDetailScreen extends StatefulWidget {
  const StockDetailScreen({super.key, required this.stockItemId});

  final String stockItemId;

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  int _delta = 0;
  StockChangeReason _reason = StockChangeReason.correction;

  Future<void> _apply(StockItem item) async {
    final stock = context.read<StockController>();
    final staff = context.read<SessionController>().staff;
    if (staff == null) return;

    final applied = await stock.adjust(item.id, _delta, _reason, staff: staff);
    if (!mounted) return;

    if (!applied) {
      final message = stock.error;
      if (message != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
        stock.clearError();
      }
      return;
    }

    HapticFeedback.mediumImpact();
    final change = _delta;
    setState(() => _delta = 0);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${item.name}: ${signed(change)} (${_reason.label})'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final stock = context.watch<StockController>();
    final staff = context.watch<SessionController>().staff;
    final item = stock.itemById(widget.stockItemId);
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    if (item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('That product is no longer listed.')),
      );
    }

    final canAdjust = staff?.role.canAdjustStock ?? false;
    final tone = item.isOutOfStock
        ? colors.outOfStock
        : item.isLow
            ? colors.lowStock
            : colors.inStock;

    return Scaffold(
      appBar: AppBar(title: Text(item.sku)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayName,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.barcode == null
                      ? 'No barcode on file'
                      : 'Barcode ${item.barcode}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Divider(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: _Figure(
                        label: 'On hand',
                        value: '${item.onHand}',
                      ),
                    ),
                    Expanded(
                      child: _Figure(
                        label: 'Reserved',
                        value: '${item.reserved}',
                      ),
                    ),
                    Expanded(
                      child: _Figure(
                        label: 'Free to sell',
                        value: '${item.available}',
                        tone: tone,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 26),
                _Line(
                  icon: Icons.place_outlined,
                  label: item.location ?? 'No bin assigned',
                ),
                const SizedBox(height: 8),
                _Line(
                  icon: Icons.event_repeat,
                  label: item.countedAt == null
                      ? 'Never counted'
                      : 'Last counted ${relativeTime(item.countedAt!)}',
                  tone: item.countedAt == null ? colors.lowStock : null,
                ),
                if (item.reorderLevel > 0) ...[
                  const SizedBox(height: 8),
                  _Line(
                    icon: Icons.notifications_none,
                    label: 'Reorder at ${item.reorderLevel}',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Adjust',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            canAdjust
                ? 'Record what changed, not what the total became.'
                : 'Your role can view stock but not change it.',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _delta == 0
                            ? 'No change'
                            : '${signed(_delta)} → ${item.onHand + _delta} on hand',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _delta == 0 ? scheme.onSurfaceVariant : tone,
                        ),
                      ),
                    ),
                    QtyStepper(
                      value: _delta,
                      // Cannot take more off the shelf than is on it.
                      min: -item.onHand,
                      onChanged: canAdjust
                          ? (value) => setState(() => _delta = value)
                          : (_) {},
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final reason in StockChangeReason.values)
                      ChoiceChip(
                        label: Text(reason.label),
                        selected: _reason == reason,
                        onSelected: canAdjust
                            ? (_) => setState(() => _reason = reason)
                            : null,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: canAdjust && _delta != 0 ? () => _apply(item) : null,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save adjustment'),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.tone});

  final String label;
  final String value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: tone,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.label, this.tone});

  final IconData icon;
  final String label;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: tone ?? scheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: tone,
              fontWeight: tone == null ? FontWeight.w400 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
