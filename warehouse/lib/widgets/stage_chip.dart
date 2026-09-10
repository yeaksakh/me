import 'package:flutter/material.dart';

import '../models/fulfilment_stage.dart';
import '../theme/app_theme.dart';

class StageChip extends StatelessWidget {
  const StageChip({super.key, required this.stage});

  final FulfilmentStage stage;

  @override
  Widget build(BuildContext context) {
    final color = context.appColors.forStage(stage);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        stage.label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
