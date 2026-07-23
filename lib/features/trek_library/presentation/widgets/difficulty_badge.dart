import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:flutter/material.dart';

/// Small colour-coded pill showing a trek's difficulty.
///
/// The colour mapping is unchanged (easy→green, moderate→gold, hard→
/// orange, extreme→red) — those [AppColors.difficulty*] tokens already
/// point at the Phase 1 palette. Restyled to the design system's pill:
/// a tinted glass fill, a signal icon, and the bold label type.
class DifficultyBadge extends StatelessWidget {
  const DifficultyBadge({super.key, required this.difficulty, this.dense = false});

  final TrekDifficulty difficulty;
  final bool dense;

  Color get _color => switch (difficulty) {
    TrekDifficulty.easy => AppColors.difficultyEasy,
    TrekDifficulty.moderate => AppColors.difficultyModerate,
    TrekDifficulty.hard => AppColors.difficultyHard,
    TrekDifficulty.extreme => AppColors.difficultyExtreme,
  };

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.sm : AppSpacing.md,
        vertical: dense ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(AppIcons.difficulty, size: dense ? 12 : 14, color: color),
          SizedBox(width: dense ? 4 : AppSpacing.xs),
          Text(
            difficulty.label,
            style: AppTextStyles.tinted(
              dense ? AppTextStyles.labelSmall : AppTextStyles.labelMedium,
              color,
            ),
          ),
        ],
      ),
    );
  }
}
