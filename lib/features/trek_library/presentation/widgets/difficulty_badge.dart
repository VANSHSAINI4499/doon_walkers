import 'package:doon_walkers/core/theme/app_colors.dart';
import 'package:doon_walkers/core/theme/app_text_styles.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:flutter/material.dart';

/// Small colour-coded pill showing a trek's difficulty.
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
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: _color.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withAlpha(90)),
      ),
      child: Text(
        difficulty.label,
        style: AppTextStyles.labelSmall.copyWith(
          color: _color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
