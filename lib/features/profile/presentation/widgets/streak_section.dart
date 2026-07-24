import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/registrations/domain/entities/trekking_streak.dart';
import 'package:doon_walkers/features/registrations/presentation/providers/registration_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current + longest **attendance** streak — consecutive months with an
/// attended trek. Placed on Profile next to the loyalty badge as the
/// member's-own-engagement pair. Renders nothing on error/loading-with-no-
/// cache rather than a spinner of its own.
///
/// This is deliberately a SEPARATE system from the Challenges module's
/// fitness (daily-activity) streaks — it is measured in *months of
/// attended treks*, not days of recorded activity. The redesign keeps it
/// visually distinct: an accent-orange "TREKKING STREAK" card that reads
/// clearly as its own thing, never merged with any Challenges content.
class StreakSection extends ConsumerWidget {
  const StreakSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(myStreakProvider);

    return streakAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
      data: (streak) {
        if (streak.longestMonths == 0) {
          // Nothing to show yet — a brand-new member with no attended
          // treks. Avoids a "0-month streak" line that reads as a failure
          // state rather than just "not started yet".
          return const SizedBox.shrink();
        }
        return _StreakCard(streak: streak);
      },
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak});

  final TrekkingStreak streak;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blurEnabled: false,
      glowColor: AppColors.accent,
      glowOpacity: streak.isActive ? 0.18 : 0.08,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: streak.isActive ? 0.18 : 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
            ),
            child: AppIcon(
              AppIcons.streak,
              color: streak.isActive ? AppColors.accent : AppColors.textSecondary,
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('TREKKING STREAK', style: AppTextStyles.tinted(AppTextStyles.overline, AppColors.accent)),
                const SizedBox(height: 2),
                Text(
                  streak.isActive ? '${streak.currentMonths}-month streak' : 'No active streak right now',
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'Longest streak: ${streak.longestMonths} month'
                  '${streak.longestMonths == 1 ? '' : 's'}',
                  style: AppTextStyles.secondary(AppTextStyles.bodySmall),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
