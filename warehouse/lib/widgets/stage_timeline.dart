import 'package:flutter/material.dart';

import '../models/fulfilment_stage.dart';
import '../theme/app_theme.dart';

/// The five-stage rail, drawn from [kStageTimeline] rather than from hand-written
/// tiles.
///
/// Drawing it from the list is not fussiness: the customer app shipped a version
/// that held six names indexed against four tiles, so `picked_up` lit the
/// Delivered circle. One list, one loop, and that class of bug cannot happen.
class StageTimeline extends StatelessWidget {
  const StageTimeline({super.key, required this.stage});

  final FulfilmentStage stage;

  static const _icons = [
    Icons.receipt_long,
    Icons.inventory_2,
    Icons.fact_check,
    Icons.local_shipping,
    Icons.done_all,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    // A cancelled order is not anywhere on this rail, so nothing lights up.
    final current = stage.step;
    final accent = colors.forStage(stage);

    return Row(
      children: [
        for (var index = 0; index < kStageTimeline.length; index++) ...[
          if (index > 0)
            Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: index <= current ? accent : scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          _Dot(
            icon: _icons[index],
            label: kStageTimeline[index].label,
            reached: index <= current,
            accent: accent,
          ),
        ],
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.icon,
    required this.label,
    required this.reached,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final bool reached;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 58,
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: reached ? accent : scheme.surfaceContainerHighest,
            ),
            child: Icon(
              icon,
              size: 18,
              color: reached ? Colors.white : scheme.outline,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              fontSize: 10,
              height: 1.2,
              fontWeight: reached ? FontWeight.w600 : FontWeight.w400,
              color: reached ? scheme.onSurface : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
