import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/staff.dart';
import '../state/session_controller.dart';
import '../state/stock_controller.dart';
import '../state/tasks_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/section_card.dart';
import '../widgets/stat_tile.dart';

/// Who is signed in, what they got through today, and the way out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final tasks = context.watch<TasksController>();
    final stock = context.watch<StockController>();
    final staff = session.staff;
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    if (staff == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text(
          'Profile',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SectionCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: scheme.primary,
                  child: Text(
                    staff.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        staff.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${staff.role.label}'
                        '${staff.staffCode == null ? '' : ' · ${staff.staffCode}'}',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      Text(
                        staff.warehouseName,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Today',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.inventory_2,
                  label: 'Prepared',
                  value: '${tasks.preparedToday}',
                  tone: colors.prepared,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  icon: Icons.fact_check,
                  label: 'Checked',
                  value: '${tasks.checkedToday}',
                  tone: colors.checked,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  icon: Icons.warehouse,
                  label: 'Units held',
                  value: '${stock.totalUnits}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'What you can do',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          SectionCard(
            child: Column(
              children: [
                _Permission(
                  label: 'Prepare orders',
                  granted: staff.role.canPrepare,
                ),
                const Divider(height: 22),
                _Permission(
                  label: 'Sign off checks',
                  granted: staff.role.canCheck,
                ),
                const Divider(height: 22),
                _Permission(
                  label: 'Change stock numbers',
                  granted: staff.role.canAdjustStock,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (stock.hasOpenCount)
            SectionCard(
              child: Row(
                children: [
                  Icon(Icons.checklist, color: colors.lowStock),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'A stock count is open with '
                      '${stock.count!.countedCount} lines counted.',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => context.read<SessionController>().signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
          ),
          const SizedBox(height: 10),
          Text(
            'Handsets are shared. Sign out at the end of your shift.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Permission extends StatelessWidget {
  const _Permission({required this.label, required this.granted});

  final String label;
  final bool granted;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          granted ? Icons.check_circle : Icons.remove_circle_outline,
          size: 20,
          color: granted ? colors.inStock : scheme.outline,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: granted ? scheme.onSurface : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
