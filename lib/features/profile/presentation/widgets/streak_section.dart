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
/// attended treks*, not days of recorded activity. Phase 14 keeps that
/// distinction in the label ("TREKKING STREAK") rather than in a
/// different colour: the calm palette has one accent, and two streak
/// systems in two hues would imply two brands.
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
    final palette = AppPalette.of(context);
    // An active streak earns the accent; a lapsed one goes neutral, which
    // is the whole signal — no glow needed to say "this one is live".
    final ink = streak.isActive ? palette.primary : palette.textSecondary;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: streak.isActive ? palette.primarySubtle : palette.cardHigh,
              shape: BoxShape.circle,
            ),
            child: AnimatedStreakFlame(
              icon: AppIcons.streak,
              color: ink,
              size: 22,
              isActive: streak.isActive,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TREKKING STREAK',
                  style: AppTextStyles.overline.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  streak.isActive
                      ? '${streak.currentMonths}-month streak'
                      : 'No active streak right now',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Longest streak: ${streak.longestMonths} month'
                  '${streak.longestMonths == 1 ? '' : 's'}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
