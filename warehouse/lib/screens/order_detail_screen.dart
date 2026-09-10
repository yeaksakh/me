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

/// One shipment, and the work of moving it on -- the website's shipment pop-up.
///
/// While it is `ordered` the flow is the website's: someone accepts it, that
/// person ticks every item into the box, then marks it packed. A supervisor then
/// marks it audited, and the rider app takes it from there.
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  /// The item a scan last landed on, so it can be flashed.
  String? _flashedLineId;

  @override
  void initState() {
    super.initState();
    // A list row carries no items: fetch them, and anything that changed since.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<TasksController>().openDetail(widget.orderId);
    });
  }

  Future<void> _handleScan(String code) async {
    final tasks = context.read<TasksController>();
    final order = tasks.orderById(widget.orderId);
    if (order == null) return;

    final target = order.lineForCode(code);
    if (target == null) {
      HapticFeedback.heavyImpact();
      showScanResult(
        context,
        outcome: ScanOutcome.unknown,
        message: '$code is not on this shipment.',
      );
      return;
    }
    if (target.packed) {
      HapticFeedback.mediumImpact();
      setState(() => _flashedLineId = target.id);
      showScanResult(
        context,
        outcome: ScanOutcome.alreadyComplete,
        message: '${target.name} is already ticked.',
      );
      return;
    }

    final ticked =
        await tasks.setLinePacked(widget.orderId, target.id, packed: true);
    if (!mounted) return;
    if (!ticked) {
      _showError(tasks);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _flashedLineId = target.id);
    showScanResult(
      context,
      outcome: ScanOutcome.accepted,
      message: '${target.name} ticked',
    );
  }

  void _showError(TasksController tasks) {
    final message = tasks.error;
    if (message == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    tasks.clearError();
  }

  /// Runs one move, then says what happened -- the server's own words when it
  /// refused, so "Already accepted by Sok Dara." reaches the person as written.
  Future<void> _run(
    Future<bool> Function(TasksController tasks) move, {
    String? done,
    bool close = false,
  }) async {
    final tasks = context.read<TasksController>();
    // Resolved before the await: after it this context may be gone.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final moved = await move(tasks);
    if (!mounted) return;
    if (!moved) {
      _showError(tasks);
      return;
    }
    HapticFeedback.mediumImpact();
    if (close) navigator.pop();
    if (done != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(done)));
    }
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
        body: const Center(child: Text('That shipment is no longer here.')),
      );
    }

    final stage = order.stage;
    final mine = order.isAcceptedBy(staff?.id);
    final packing = stage == FulfilmentStage.ordered && mine;
    final waiting = tasks.busy;

    return Scaffold(
      appBar: AppBar(
        title: Text(order.code),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: StageChip(stage: stage)),
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
                StageTimeline(stage: stage),
                const Divider(height: 28),
                _Row(icon: Icons.person_outline, label: order.customerName),
                if (order.customerPhone.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _Row(icon: Icons.phone_outlined, label: order.customerPhone),
                ],
                if (order.shippingAddress.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _Row(
                    icon: Icons.location_on_outlined,
                    label: order.shippingAddress,
                  ),
                ],
                if (order.locationName.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _Row(icon: Icons.store_outlined, label: order.locationName),
                ],
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
                if (order.note.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _Row(icon: Icons.sticky_note_2_outlined, label: order.note),
                ],
              ],
            ),
          ),
          if (stage == FulfilmentStage.ordered && !order.isAccepted) ...[
            const SizedBox(height: 12),
            _Banner(
              icon: Icons.assignment_ind_outlined,
              color: colors.ordered,
              title: 'Not accepted yet',
              message: 'Accept it to start packing. The website shows you as '
                  'the one preparing it.',
            ),
          ],
          if (stage == FulfilmentStage.ordered &&
              order.isAccepted &&
              !mine) ...[
            const SizedBox(height: 12),
            _Banner(
              icon: Icons.person_pin_outlined,
              color: scheme.onSurfaceVariant,
              title: 'Being packed by ${order.preparedBy!.name}',
              message: 'Only the person who accepted a shipment ticks its items.',
            ),
          ],
          if (order.isCashOnDelivery) ...[
            const SizedBox(height: 12),
            _Banner(
              icon: Icons.payments,
              color: colors.prepared,
              title: 'Collect on delivery',
              message:
                  'Put the invoice in the box. The rider collects at the door.',
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Items',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${order.packedCount} / ${order.lineCount} packed',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: order.isFullyPacked ? colors.inStock : colors.lowStock,
                ),
              ),
            ],
          ),
          if (packing) ...[
            const SizedBox(height: 12),
            ScanField(onScan: _handleScan, hintText: 'Scan or type a SKU'),
            const SizedBox(height: 6),
            Text(
              'A scan ticks the matching item. Or tap an item.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          if (!order.hasDetail)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          for (final line in order.lines) ...[
            PickLineTile(
              line: line,
              highlighted: _flashedLineId == line.id,
              onPackedChanged: packing && !waiting
                  ? (value) => _run((tasks) =>
                      tasks.setLinePacked(order.id, line.id, packed: value))
                  : null,
            ),
            const SizedBox(height: 10),
          ],
          if (order.photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Photos',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final photo in order.photos)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      photo.url,
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 84,
                        height: 84,
                        color: scheme.surfaceContainerHighest,
                        child: Icon(Icons.broken_image, color: scheme.outline),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          ..._actions(order, staff: staff, mine: mine, waiting: waiting),
        ],
      ),
    );
  }

  List<Widget> _actions(
    Order order, {
    required Staff? staff,
    required bool mine,
    required bool waiting,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final stage = order.stage;

    if (stage == FulfilmentStage.ordered && !order.isAccepted) {
      return [
        ElevatedButton.icon(
          onPressed: waiting
              ? null
              : () => _run(
                    (tasks) => tasks.accept(order.id),
                    done: 'You are packing ${order.code}.',
                  ),
          icon: const Icon(Icons.assignment_ind),
          label: const Text('Accept to pack'),
        ),
      ];
    }

    if (stage == FulfilmentStage.ordered && mine) {
      return [
        ElevatedButton.icon(
          onPressed: waiting || !order.isFullyPacked
              ? null
              : () => _run(
                    (tasks) => tasks.markPacked(order.id),
                    done: '${order.code} packed — waiting for audit.',
                    close: true,
                  ),
          icon: const Icon(Icons.inventory_2),
          label: const Text('Mark packed'),
        ),
        if (!order.isFullyPacked && order.hasDetail) ...[
          const SizedBox(height: 8),
          Text(
            'Tick every item first (${order.unpackedCount} left).',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
        // The server refuses to hand back a shipment once an item is ticked,
        // so the button only exists while it would work.
        if (order.packedCount == 0) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: waiting
                ? null
                : () => _run(
                      (tasks) => tasks.release(order.id),
                      done: '${order.code} handed back.',
                      close: true,
                    ),
            icon: const Icon(Icons.undo),
            label: const Text('Hand back'),
          ),
        ],
      ];
    }

    if (stage == FulfilmentStage.ordered) return const [];

    if (stage == FulfilmentStage.packed) {
      if (staff != null && staff.role.canCheck) {
        return [
          ElevatedButton.icon(
            onPressed: waiting
                ? null
                : () => _run(
                      (tasks) => tasks.markAudited(order.id, staff: staff),
                      done: '${order.code} audited — waiting for the rider.',
                      close: true,
                    ),
            icon: const Icon(Icons.fact_check),
            label: const Text('Mark audited'),
          ),
        ];
      }
      return [
        _Banner(
          icon: Icons.lock_outline,
          color: scheme.onSurfaceVariant,
          title: 'Waiting for audit',
          message: 'A supervisor checks the packed shipment before the rider '
              'takes it.',
        ),
      ];
    }

    if (stage == FulfilmentStage.audited) {
      return [
        _Banner(
          icon: Icons.local_shipping,
          color: colors.checked,
          title: 'Waiting for the rider',
          message: 'The rider marks it picked up from the rider app.',
        ),
      ];
    }

    return [
      _Banner(
        icon: Icons.done_all,
        color: colors.forStage(stage),
        title: stage.label,
        message: 'This shipment has left the warehouse.',
      ),
    ];
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
