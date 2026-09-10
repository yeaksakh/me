import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/fulfilment_stage.dart';
import '../state/session_controller.dart';
import '../state/stock_controller.dart';
import '../state/tasks_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/order_task_card.dart';
import '../widgets/stat_tile.dart';
import 'order_detail_screen.dart';

/// The floor's three queues, one tab each, in the order work moves through them.
class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

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
              if (staff != null)
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
                          stage.queueLabel,
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
    if (count == 0) return const SizedBox.shrink();
    return Container(
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
    );
  }
}

class _Queue extends StatelessWidget {
  const _Queue({required this.stage});

  final FulfilmentStage stage;

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TasksController>();
    final orders = tasks.queue(stage);

    if (tasks.loading && tasks.all.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        // Both controllers are resolved before the first await: a lookup on the
        // far side of one runs against a context that may already be gone.
        final tasksController = context.read<TasksController>();
        final stockController = context.read<StockController>();
        await tasksController.load();
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
                      final copy = emptyQueueCopy(stage);
                      return EmptyState(
                        icon: copy.icon,
                        title: copy.title,
                        message: copy.message,
                      );
                    },
                  ),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: orders.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) return _Summary(stage: stage);
                final order = orders[index - 1];
                return OrderTaskCard(
                  order: order,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OrderDetailScreen(orderId: order.id),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// The three numbers worth knowing at a glance, above the queue.
class _Summary extends StatelessWidget {
  const _Summary({required this.stage});

  final FulfilmentStage stage;

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TasksController>();
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: StatTile(
              icon: Icons.inbox,
              label: 'In the building',
              value: '${tasks.openCount}',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatTile(
              icon: Icons.fact_check,
              label: 'Checked today',
              value: '${tasks.checkedToday}',
              tone: colors.checked,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatTile(
              icon: Icons.local_shipping,
              label: 'Awaiting driver',
              value: '${tasks.awaitingDriver}',
              tone: colors.pickedUp,
            ),
          ),
        ],
      ),
    );
  }
}
