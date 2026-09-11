import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/motion.dart';
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

  /// Tabs on stage: the selected one, and any still fading out. Everything
  /// else is offstage -- hidden from a screen reader and from hit-testing,
  /// but kept built so its state survives.
  final Set<int> _staged = {0};

  void _select(int value) {
    setState(() {
      _index = value;
      _staged.add(value);
    });
  }

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
      (
        icon: Icons.assignment_outlined,
        active: Icons.assignment,
        label: 'Orders',
        color: colors.orders
      ),
      (
        icon: Icons.inventory_2_outlined,
        active: Icons.inventory_2,
        label: 'Stock',
        color: colors.stock
      ),
      (
        icon: Icons.badge_outlined,
        active: Icons.badge,
        label: 'HRM',
        color: colors.hrm
      ),
      (
        icon: Icons.person_outline,
        active: Icons.person,
        label: 'Profile',
        color: colors.holiday
      ),
    ];
    final current = areas[_index].color;

    return Scaffold(
      // Every tab stays built, so a scroll position or a half-typed search
      // survives a visit elsewhere; the one on show cross-fades and lifts in.
      // Only the visible tab ticks, so a hidden one costs nothing.
      body: Stack(
        children: [
          for (var i = 0; i < _tabs.length; i++)
            Offstage(
              offstage: !_staged.contains(i),
              child: IgnorePointer(
                ignoring: i != _index,
                child: AnimatedOpacity(
                  opacity: i == _index ? 1 : 0,
                  duration: kMotion,
                  curve: Curves.easeOut,
                  onEnd: () {
                    if (i != _index && mounted) {
                      setState(() => _staged.remove(i));
                    }
                  },
                  child: AnimatedSlide(
                    offset: Offset(0, i == _index ? 0 : 0.015),
                    duration: kMotion,
                    curve: Curves.easeOutCubic,
                    // Inside the fade, not around it: a muted ticker would
                    // freeze the fade-out itself, and the tab would never go
                    // offstage.
                    child: TickerMode(
                      enabled: i == _index,
                      child: _tabs[i],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
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
          onDestinationSelected: _select,
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
