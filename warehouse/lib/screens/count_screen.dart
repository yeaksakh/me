import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/staff.dart';
import '../models/stock_count.dart';
import '../state/session_controller.dart';
import '../state/stock_controller.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/empty_state.dart';
import '../widgets/qty_stepper.dart';
import '../widgets/scan_field.dart';
import '../widgets/section_card.dart';
import '../widgets/stat_tile.dart';

/// Stock counting: open a count, walk the shelves, submit.
///
/// Nothing on the shelf changes until Submit. That is what makes it safe to
/// count over a whole shift, hand the handset to the next person, and correct a
/// line you got wrong twenty aisles ago.
class CountScreen extends StatefulWidget {
  const CountScreen({super.key});

  @override
  State<CountScreen> createState() => _CountScreenState();
}

class _CountScreenState extends State<CountScreen> {
  bool _onlyUncounted = false;

  Future<void> _handleScan(String code) async {
    final stock = context.read<StockController>();
    final line = stock.applyScanToCount(code);
    if (!mounted) return;

    if (line == null) {
      HapticFeedback.heavyImpact();
      showScanResult(
        context,
        outcome: ScanOutcome.unknown,
        message: '$code is not in this count.',
      );
      return;
    }

    HapticFeedback.selectionClick();
    showScanResult(
      context,
      outcome: ScanOutcome.accepted,
      message: '${line.name}: counted ${line.counted}',
    );
  }

  Future<void> _submit(StockCount count) async {
    final stock = context.read<StockController>();
    final staff = context.read<SessionController>().staff;
    if (staff == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Submit this count?'),
        content: Text(
          count.remainingCount > 0
              ? '${count.countedCount} counted, ${count.remainingCount} not '
                  'counted.\n\nUncounted lines are left exactly as they are. '
                  'Counted lines overwrite the shelf.'
              : 'All ${count.lines.length} lines counted.\n\n'
                  'Net change: ${signed(count.netVariance)} units across '
                  '${count.variances.length} lines.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep counting'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final variance = count.netVariance;
    final lines = count.countedCount;
    final done = await stock.submitCount(staff: staff);
    if (!mounted) return;

    if (!done) {
      final message = stock.error;
      if (message != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
        stock.clearError();
      }
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Count submitted: $lines lines, ${signed(variance)} units net.',
          ),
        ),
      );
  }

  Future<void> _discard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard this count?'),
        content: const Text(
          'Everything counted so far is thrown away. The shelf is untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    context.read<StockController>().discardCount();
  }

  @override
  Widget build(BuildContext context) {
    final stock = context.watch<StockController>();
    final staff = context.watch<SessionController>().staff;
    final count = stock.count;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text(
          'Stock count',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (count != null)
            IconButton(
              onPressed: _discard,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Discard count',
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: count == null ? _startPane(stock) : _countPane(stock, count),
      bottomNavigationBar: count == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: ElevatedButton.icon(
                  onPressed: (staff?.role.canAdjustStock ?? false) &&
                          count.countedCount > 0
                      ? () => _submit(count)
                      : null,
                  icon: const Icon(Icons.check),
                  label: Text(
                    count.countedCount == 0
                        ? 'Count something to submit'
                        : 'Submit ${plural(count.countedCount, "line")}',
                  ),
                ),
              ),
            ),
    );
  }

  Widget _startPane(StockController stock) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // No fixed height: EmptyState sizes to its content, and pinning it to a
        // guessed number is what made it overflow on a short screen.
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: EmptyState(
            icon: Icons.checklist,
            title: 'No count open',
            message:
                'Start one, walk the shelves, and submit when you are done.',
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => stock.startCount(),
          icon: const Icon(Icons.play_arrow),
          label: Text('Count everything (${stock.all.length} products)'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: stock.needsAttention.isEmpty
              ? null
              : () => stock.startCount(items: stock.needsAttention),
          icon: const Icon(Icons.priority_high),
          label: Text(
            stock.needsAttention.isEmpty
                ? 'Nothing low or out'
                : 'Count low and out only (${stock.needsAttention.length})',
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'A count in progress is kept on this device, so it survives a '
          'restart or a flat battery.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _countPane(StockController stock, StockCount count) {
    final colors = context.appColors;
    final lines = _onlyUncounted
        ? count.lines.where((line) => !line.isCounted).toList()
        : count.lines;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      icon: Icons.done,
                      label: 'Counted',
                      value: '${count.countedCount}',
                      tone: colors.inStock,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatTile(
                      icon: Icons.pending_outlined,
                      label: 'Left',
                      value: '${count.remainingCount}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatTile(
                      icon: Icons.difference,
                      label: 'Variance',
                      value: signed(count.netVariance),
                      tone: count.netVariance == 0
                          ? colors.inStock
                          : colors.lowStock,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ScanField(
                onScan: _handleScan,
                hintText: 'Scan a shelf item',
                autofocus: false,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Started ${relativeTime(count.startedAt)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  FilterChip(
                    label: const Text('Only uncounted'),
                    selected: _onlyUncounted,
                    onSelected: (value) =>
                        setState(() => _onlyUncounted = value),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: lines.isEmpty
              ? const EmptyState(
                  icon: Icons.done_all,
                  title: 'Every line counted',
                  message: 'Submit when you are ready.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: lines.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _CountLineTile(
                    line: lines[index],
                    onChanged: (value) =>
                        stock.setCounted(lines[index].stockItemId, value),
                  ),
                ),
        ),
      ],
    );
  }
}

class _CountLineTile extends StatelessWidget {
  const _CountLineTile({required this.line, required this.onChanged});

  final CountLine line;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    final variance = line.variance;
    final tone = !line.isCounted
        ? scheme.onSurfaceVariant
        : variance == 0
            ? colors.inStock
            : colors.lowStock;

    return SectionCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (line.location != null)
                      Text(
                        line.location!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Book ${line.expected}',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (line.isCounted)
                    Text(
                      variance == 0 ? 'Matches' : signed(variance!),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: tone,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: line.isCounted
                    ? Text(
                        'Counted ${line.counted}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: tone,
                        ),
                      )
                    : Text(
                        'Not counted yet',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
              ),
              if (line.isCounted)
                IconButton(
                  onPressed: () => onChanged(null),
                  icon: const Icon(Icons.backspace_outlined),
                  tooltip: 'Clear',
                ),
              QtyStepper(
                value: line.counted ?? 0,
                onChanged: onChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
