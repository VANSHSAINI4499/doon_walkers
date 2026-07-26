import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:flutter/material.dart';

/// Small colour-coded pill showing a trek's difficulty.
///
/// The colour mapping is unchanged (easy→green, moderate→gold, hard→
/// orange, extreme→red) — [AppPalette.difficultyEasy] et al. already point
/// at the calm palette. Redesign 2.0 Phase 15 drops the glass tint for a
/// flat, dual-tone pill: a soft fill in the difficulty colour, no border
/// glow — reads at a glance without competing with the card's own hairline.
class DifficultyBadge extends StatelessWidget {
  const DifficultyBadge({super.key, required this.difficulty, this.dense = false});

  final TrekDifficulty difficulty;
  final bool dense;

  Color _color(AppPalette palette) => switch (difficulty) {
    TrekDifficulty.easy => palette.difficultyEasy,
    TrekDifficulty.moderate => palette.difficultyModerate,
    TrekDifficulty.hard => palette.difficultyHard,
    TrekDifficulty.extreme => palette.difficultyExtreme,
  };

  @override
  Widget build(BuildContext context) {
    final color = _color(AppPalette.of(context));
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.sm : AppSpacing.md,
        vertical: dense ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(AppIcons.difficulty, size: dense ? 12 : 14, color: color),
          SizedBox(width: dense ? 4 : AppSpacing.xs),
          Text(
            difficulty.label,
            style:
                (dense ? AppTextStyles.labelSmall : AppTextStyles.labelMedium)
                    .copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
