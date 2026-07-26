import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/widgets/view_all_button.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/level_badge.dart';
import 'package:doon_walkers/features/profile/presentation/providers/points_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Total points, level, and a progress bar toward the next level, plus a
/// "View History" link to the full ledger — Phase 22.
///
/// All figures come from `get_my_points_summary()`
/// (0039_points_history_and_enrollment_fix.sql); the level ladder itself
/// is never recomputed here. Reuses [LevelBadge] (Phase 21) so there is
/// one level-badge widget in the codebase, not two.
class PointsSummarySection extends ConsumerWidget {
  const PointsSummarySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final summaryAsync = ref.watch(myPointsSummaryProvider);

    return summaryAsync.when(
      loading: () => const AppCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: SkeletonStatRow(),
        ),
      ),
      error: (error, stack) {
        debugPrint('PointsSummarySection: failed to load points summary: $error');
        return AppCard(
          child: Text(
            'Points unavailable right now.',
            style: AppTextStyles.bodySmall.copyWith(color: palette.textSecondary),
            textAlign: TextAlign.center,
          ),
        );
      },
      data: (summary) {
        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    '${summary.totalPoints}',
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      'points',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  LevelBadge(level: summary.level),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppProgressBar(
                value: summary.progressToNextLevel,
                label: summary.isMaxLevel
                    ? 'Top level reached'
                    : 'Progress to Level ${summary.nextLevel}',
                trailing: summary.isMaxLevel
                    ? null
                    : '${summary.pointsToNextLevel} to go',
              ),
              const SizedBox(height: AppSpacing.sm),
              ViewAllButton(
                label: 'View History',
                onTap: () => context.push(AppConstants.routePointsHistory),
              ),
            ],
          ),
        );
      },
    );
  }
}
