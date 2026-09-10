import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/fulfilment_stage.dart';
import '../state/session_controller.dart';
import '../state/stock_controller.dart';
import '../state/tasks_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/motion.dart';
import '../widgets/order_task_card.dart';
import 'order_detail_screen.dart';

/// The shipments, one tab per status, as the website's /shipments page filters
/// them: Ordered, Packed, Audited.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  @override
  void initState() {
    super.initState();
    // After the first frame: loading notifies listeners, and doing that while
    // this widget is still building is an error.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<TasksController>().refreshAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final tasks = context.watch<TasksController>();
    final staff = session.staff;

    return DefaultTabController(
      length: kStaffQueues.length,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 20,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Orders',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              if (staff != null && staff.warehouseName.isNotEmpty)
                Text(
                  staff.warehouseName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          bottom: TabBar(
            tabs: [
              for (final stage in kStaffQueues)
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Flexible rather than bare Text: on the narrowest phones
                      // the label yields before it can overflow the tab.
                      Flexible(
                        child: Text(
                          stage.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _Badge(
                        count: tasks.queueCount(stage),
                        color: context.appColors.forStage(stage),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            for (final stage in kStaffQueues) _Queue(stage: stage),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Morph(
      child: count == 0
          ? const SizedBox.shrink(key: ValueKey('none'))
          : Container(
              key: ValueKey(count),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withAlpha(36),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
    );
  }
}

class _Queue extends StatelessWidget {
  const _Queue({required this.stage});

  final FulfilmentStage stage;

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TasksController>();
    final staffId = context.select<SessionController, String?>(
      (session) => session.staff?.id,
    );
    final orders = tasks.queue(stage);

    if (!tasks.hasLoaded(stage) && tasks.error == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        // Both controllers are resolved before the first await: a lookup on the
        // far side of one runs against a context that may already be gone.
        final tasksController = context.read<TasksController>();
        final stockController = context.read<StockController>();
        await tasksController.refreshAll();
        await stockController.load();
      },
      child: orders.isEmpty
          ? ListView(
              // A scrollable is needed for pull-to-refresh to work on an
              // otherwise empty tab.
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.6,
                  child: Builder(
                    builder: (context) {
                      // A tab that never loaded is a failure to say out loud,
                      // not an empty queue: "Nothing to pack" would be a lie.
                      final failed = !tasks.hasLoaded(stage);
                      final copy = emptyQueueCopy(stage);
                      return EmptyState(
                        icon: failed ? Icons.cloud_off : copy.icon,
                        title: failed ? 'Could not load shipments' : copy.title,
                        message: failed
                            ? '${tasks.error ?? ''}\nPull down to try again.'
                            : copy.message,
                      );
                    },
                  ),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final order = orders[index];
                return Appear(
                  key: ValueKey(order.id),
                  index: index,
                  child: OrderTaskCard(
                    order: order,
                    staffId: staffId,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OrderDetailScreen(orderId: order.id),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
