import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/fulfilment_stage.dart';
import '../models/order.dart';
import '../models/staff.dart';
import '../state/session_controller.dart';
import '../state/tasks_controller.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/pick_line_tile.dart';
import '../widgets/scan_field.dart';
import '../widgets/section_card.dart';
import '../widgets/stage_chip.dart';
import '../widgets/stage_timeline.dart';

/// One order, and the work of moving it forward.
///
/// The same screen serves both warehouse stages. Picking is editable while the
/// order is at `ordered`; at `prepared` the numbers freeze and the job becomes
/// verifying them, which is the whole point of having two stages and would be
/// undone by letting the checker quietly fix the counts.
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  /// The line a scan last landed on, so it can be flashed.
  String? _flashedLineId;

  Future<void> _handleScan(String code) async {
    final tasks = context.read<TasksController>();
    final order = tasks.orderById(widget.orderId);
    if (order == null) return;

    final target = order.lineForCode(code);
    if (target == null) {
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      showScanResult(
        context,
        outcome: ScanOutcome.unknown,
        message: '$code is not on this order.',
      );
      return;
    }

    if (target.isComplete) {
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() => _flashedLineId = target.id);
      showScanResult(
        context,
        outcome: ScanOutcome.alreadyComplete,
        message: '${target.name}: all ${target.quantity} already picked.',
      );
      return;
    }

    await tasks.applyScan(widget.orderId, code);
    HapticFeedback.selectionClick();
    if (!mounted) return;
    setState(() => _flashedLineId = target.id);
    showScanResult(
      context,
      outcome: ScanOutcome.accepted,
      message: '${target.name}  ${target.picked}/${target.quantity}',
    );
  }

  Future<void> _advance(Order order) async {
    final tasks = context.read<TasksController>();
    final staff = context.read<SessionController>().staff;
    if (staff == null) return;

    // A short pick needs a reason before it can move on. Ask for it here rather
    // than only refusing, so the packer is not left guessing what to do next.
    if (order.hasShortage && (order.staffNote?.isEmpty ?? true)) {
      final note = await _promptNote(order);
      if (note == null || note.trim().isEmpty) return;
      await tasks.setNote(order.id, note);
    }

    final moved = await tasks.advance(order.id, staff: staff);
    if (!mounted) return;

    if (!moved) {
      final message = tasks.error;
      if (message != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
        tasks.clearError();
      }
      return;
    }

    HapticFeedback.mediumImpact();
    final now = tasks.orderById(order.id)?.stage;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            now == FulfilmentStage.checked
                ? '${order.code} checked — waiting for a driver.'
                : '${order.code} prepared — sent for checking.',
          ),
        ),
      );
  }

  Future<void> _sendBack(Order order) async {
    final tasks = context.read<TasksController>();
    final staff = context.read<SessionController>().staff;
    if (staff == null) return;

    final note = await _promptNote(
      order,
      title: 'Send back to packing',
      hint: 'What is wrong with it?',
    );
    if (note == null) return;
    await tasks.setNote(order.id, note);

    final moved = await tasks.sendBack(order.id, staff: staff);
    if (!mounted) return;
    if (!moved) {
      final message = tasks.error;
      if (message != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
        tasks.clearError();
      }
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('${order.code} sent back to packing.')),
      );
  }

  Future<String?> _promptNote(
    Order order, {
    String title = 'Add a note',
    String hint = 'Why is this order short?',
  }) {
    final controller = TextEditingController(text: order.staffNote ?? '');
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TasksController>();
    final staff = context.watch<SessionController>().staff;
    final order = tasks.orderById(widget.orderId);
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    if (order == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('That order is no longer here.')),
      );
    }

    final picking = order.stage == FulfilmentStage.ordered;
    final actionLabel = order.stage.staffActionLabel;
    final canAct = actionLabel != null &&
        staff != null &&
        (order.stage != FulfilmentStage.prepared || staff.role.canCheck);

    return Scaffold(
      appBar: AppBar(
        title: Text(order.code),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: StageChip(stage: order.stage)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StageTimeline(stage: order.stage),
                const Divider(height: 28),
                _Row(
                  icon: Icons.person_outline,
                  label: order.customerName,
                ),
                const SizedBox(height: 8),
                _Row(
                  icon: Icons.location_on_outlined,
                  label: order.shippingAddress,
                ),
                const SizedBox(height: 8),
                _Row(
                  icon: order.isCashOnDelivery
                      ? Icons.payments_outlined
                      : Icons.credit_score,
                  label: order.paymentStatus.label,
                  tone: order.isCashOnDelivery ? colors.prepared : null,
                ),
                const SizedBox(height: 8),
                _Row(
                  icon: Icons.schedule,
                  label: 'Ordered ${relativeTime(order.placedAt)}'
                      ' · ${clockTime(order.placedAt)}',
                ),
              ],
            ),
          ),
          if (order.isCashOnDelivery) ...[
            const SizedBox(height: 12),
            _Banner(
              icon: Icons.payments,
              color: colors.prepared,
              title: 'Cash on delivery',
              message:
                  'The rider collects at the door. Put the invoice in the box.',
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  picking ? 'Pick these' : 'Check these',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${order.pickedCount} / ${order.unitCount}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: order.isFullyPicked ? colors.inStock : colors.lowStock,
                ),
              ),
            ],
          ),
          if (picking) ...[
            const SizedBox(height: 12),
            ScanField(onScan: _handleScan),
            const SizedBox(height: 6),
            Text(
              'Each scan adds one. Or set the number by hand.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          for (final line in order.lines) ...[
            PickLineTile(
              line: line,
              enabled: picking,
              highlighted: _flashedLineId == line.id,
              onPickedChanged: (value) => context
                  .read<TasksController>()
                  .setLinePicked(order.id, line.id, value),
            ),
            const SizedBox(height: 10),
          ],
          if (order.hasShortage) ...[
            const SizedBox(height: 2),
            _Banner(
              icon: Icons.warning_amber,
              color: colors.lowStock,
              title: 'Short by ${order.unitCount - order.pickedCount}',
              message: order.staffNote == null
                  ? 'Add a note saying why before this order moves on.'
                  : order.staffNote!,
            ),
          ],
          if (order.staffNote != null && !order.hasShortage) ...[
            const SizedBox(height: 2),
            _Banner(
              icon: Icons.sticky_note_2_outlined,
              color: scheme.primary,
              title: 'Note',
              message: order.staffNote!,
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              final note = await _promptNote(
                order,
                title: order.staffNote == null ? 'Add a note' : 'Edit note',
                hint: 'Damaged, substituted, short…',
              );
              if (note == null) return;
              if (!context.mounted) return;
              await context.read<TasksController>().setNote(order.id, note);
            },
            icon: const Icon(Icons.edit_note),
            label: Text(order.staffNote == null ? 'Add a note' : 'Edit note'),
          ),
          if (order.stage == FulfilmentStage.prepared &&
              (staff?.role.canCheck ?? false)) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _sendBack(order),
              icon: const Icon(Icons.undo),
              label: const Text('Send back to packing'),
              style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
            ),
          ],
          const SizedBox(height: 20),
          if (canAct)
            ElevatedButton.icon(
              onPressed: () => _advance(order),
              icon: Icon(
                order.stage == FulfilmentStage.ordered
                    ? Icons.inventory_2
                    : Icons.fact_check,
              ),
              label: Text(actionLabel),
            )
          else if (order.stage == FulfilmentStage.prepared)
            _Banner(
              icon: Icons.lock_outline,
              color: scheme.onSurfaceVariant,
              title: 'Waiting for a checker',
              message:
                  'A checker or supervisor signs this off. You packed it, so '
                  'someone else confirms it.',
            )
          else if (order.stage == FulfilmentStage.checked)
            _Banner(
              icon: Icons.local_shipping,
              color: colors.checked,
              title: 'Packed and waiting',
              message:
                  'The rider marks this picked up when they collect it, from '
                  'the driver app.',
            )
          else
            _Banner(
              icon: Icons.done_all,
              color: colors.delivered,
              title: order.stage.label,
              message: 'This order has left the warehouse.',
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, this.tone});

  final IconData icon;
  final String label;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(message, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
