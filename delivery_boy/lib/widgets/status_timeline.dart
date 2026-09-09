import 'package:flutter/material.dart';

import '../models/order.dart';
import '../theme/app_theme.dart';

/// Vertical progress rail showing how far along a delivery is.
class StatusTimeline extends StatelessWidget {
  const StatusTimeline({super.key, required this.current});

  final OrderStatus current;

  static const _steps = [
    OrderStatus.accepted,
    OrderStatus.pickedUp,
    OrderStatus.onTheWay,
    OrderStatus.delivered,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final currentIndex = _steps.indexOf(current);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_steps.length, (index) {
        final step = _steps[index];
        final reached = currentIndex >= index && currentIndex != -1;
        final isLast = index == _steps.length - 1;
        final color = reached ? colors.forStatus(step) : scheme.outlineVariant;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: reached ? color : Colors.transparent,
                      border: Border.all(color: color, width: 2),
                    ),
                    child: reached
                        ? Icon(Icons.check, size: 12, color: colors.card)
                        : null,
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        color: color,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                child: Text(
                  step.label,
                  style: TextStyle(
                    fontWeight: reached ? FontWeight.w600 : FontWeight.w400,
                    color: reached ? scheme.onSurface : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
