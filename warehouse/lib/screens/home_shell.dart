import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'hrm_screen.dart';
import 'profile_screen.dart';
import 'stock_screen.dart';
import 'tasks_screen.dart';

/// Bottom-tab container. Four areas, because a fifth would not fit a thumb.
///
/// A stock count lives inside Stock rather than on a tab of its own: it is a
/// rare job, and the HR tab -- clocking in, leave, pay -- is a daily one.
///
/// Each tab wears the colour of its area, so the bar reads the way the screens
/// behind it do: the selected tab's pill, icon and label take that colour, and
/// the others keep theirs, dimmed.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _tabs = [
    TasksScreen(),
    StockScreen(),
    HrmScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final areas = [
      (icon: Icons.assignment_outlined, active: Icons.assignment, label: 'Orders', color: colors.orders),
      (icon: Icons.inventory_2_outlined, active: Icons.inventory_2, label: 'Stock', color: colors.stock),
      (icon: Icons.badge_outlined, active: Icons.badge, label: 'HRM', color: colors.hrm),
      (icon: Icons.person_outline, active: Icons.person, label: 'Profile', color: colors.holiday),
    ];
    final current = areas[_index].color;

    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: colors.card,
          indicatorColor: current.withAlpha(40),
          labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
                fontSize: 12,
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w800
                    : FontWeight.w500,
                color: states.contains(WidgetState.selected)
                    ? current
                    : scheme.onSurfaceVariant,
              )),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
          destinations: [
            for (final area in areas)
              NavigationDestination(
                icon: Icon(area.icon, color: area.color.withAlpha(170)),
                selectedIcon: Icon(area.active, color: area.color),
                label: area.label,
              ),
          ],
        ),
      ),
    );
  }
}
