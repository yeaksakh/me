import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/hrm.dart';
import '../state/hrm_controller.dart';
import '../utils/formatters.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_card.dart';
import 'hrm_screen.dart';
import 'leave_request_screen.dart';

/// The person's own leave requests, newest first, and the way to ask for more.
class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HrmController>().loadLeaves();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hrm = context.watch<HrmController>();
    final scheme = Theme.of(context).colorScheme;
    final leaves = hrm.leaves.toList()
      ..sort((a, b) => b.start.compareTo(a.start));

    return Scaffold(
      appBar: AppBar(title: const Text('Leave')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LeaveRequestScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Request leave'),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<HrmController>().loadLeaves(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            if (hrm.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(hrm.error!, style: TextStyle(color: scheme.error)),
              ),
            if (leaves.isEmpty)
              const SizedBox(
                height: 300,
                child: EmptyState(
                  icon: Icons.event_busy,
                  title: 'No leave requests',
                  message: 'Ask for leave with the button below. A manager '
                      'approves it on the website or in this app.',
                ),
              ),
            for (final leave in leaves) ...[
              LeaveCard(leave: leave),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class LeaveCard extends StatelessWidget {
  const LeaveCard({super.key, required this.leave, this.showName = false, this.onTap});

  final LeaveRequest leave;

  /// True on a manager's list, where whose request it is matters.
  final bool showName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      onTap: onTap,
      accent: leaveColor(context, leave.status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  showName && leave.userName.isNotEmpty
                      ? leave.userName
                      : leave.typeLabel,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              StatusChip(
                label: leave.status.label,
                color: leaveColor(context, leave.status),
              ),
            ],
          ),
          if (showName) ...[
            const SizedBox(height: 2),
            Text(leave.typeLabel, style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 8),
          Text(
            '${dateRange(leave.start, leave.end)}  ·  ${leave.daysLabel}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (leave.reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              leave.reason,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
          if (leave.adminRemarks.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Manager: ${leave.adminRemarks}',
              style: TextStyle(fontSize: 13, color: scheme.primary),
            ),
          ],
        ],
      ),
    );
  }
}
