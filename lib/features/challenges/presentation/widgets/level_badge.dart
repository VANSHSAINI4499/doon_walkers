import 'package:doon_walkers/core/design_system.dart';
import 'package:flutter/material.dart';

/// A compact pill badge showing "Lv. N" — used on leaderboard rows,
/// top participants, and any surface where a user's level should be
/// visible alongside their name.
///
/// Phase 21: pairs with [myUserPointsProvider] and
/// [ChallengeTopParticipant.level].
class LevelBadge extends StatelessWidget {
  const LevelBadge({super.key, required this.level, this.compact = false});

  /// The user's level integer (1–8, as returned by user_points.level).
  final int level;

  /// If true, renders as a small square chip (for dense lists).
  /// If false, renders as a wider pill with "Lv." prefix.
  final bool compact;

  /// Accent gradient hue progression per level, consistent with the
  /// design system palette.
  static Color _colorForLevel(int level) {
    return switch (level) {
      1 => const Color(0xFF78909C), // slate — base
      2 => const Color(0xFF66BB6A), // soft green
      3 => const Color(0xFF26A69A), // teal
      4 => const Color(0xFF42A5F5), // sky blue
      5 => const Color(0xFF7E57C2), // violet
      6 => const Color(0xFFEC407A), // rose
      7 => const Color(0xFFFF7043), // deep orange
      _ => const Color(0xFFFFCA28), // golden amber — max (8+)
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForLevel(level);
    final label = compact ? '$level' : 'Lv. $level';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.xs : AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
