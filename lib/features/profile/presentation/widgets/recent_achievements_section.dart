import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/widgets/view_all_button.dart';
import 'package:doon_walkers/features/activity/domain/entities/user_achievement.dart';
import 'package:doon_walkers/features/activity/presentation/providers/activity_dashboard_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Shows the 3 most recent achievements as small chips (icon + label),
/// with a "View All" button navigating to the full achievements screen.
///
/// Phase 25. If there are zero achievements, this section returns
/// [SizedBox.shrink()] (shows nothing) so as not to clutter the Profile
/// screen for new users.
class RecentAchievementsSection extends ConsumerWidget {
  const RecentAchievementsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final achievementsAsync = ref.watch(
      myAchievementsProvider((limit: 3, offset: 0)),
    );

    return achievementsAsync.when(
      loading: () => const _RecentAchievementsSkeleton(),
      error: (error, stack) {
        debugPrint('RecentAchievementsSection: failed to load: $error');
        return const SizedBox.shrink();
      },
      data: (achievements) {
        if (achievements.isEmpty) {
          return const SizedBox.shrink();
        }

        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Achievements',
                    style: AppTextStyles.titleSmall.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                  ViewAllButton(
                    label: 'View All',
                    onTap: () => context.push(AppConstants.routeAchievements),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children:
                    achievements.asMap().entries.map((entry) {
                      final index = entry.key;
                      final achievement = entry.value;
                      return AppScaleReveal(
                        index: index,
                        duration: AppMotion.medium,
                        child: _AchievementChip(achievement: achievement),
                      );
                    }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AchievementChip extends StatelessWidget {
  const _AchievementChip({required this.achievement});

  final UserAchievement achievement;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    // Dynamic icon based on type
    final icon = switch (achievement.achievementType) {
      'level_milestone' => AppIcons.star,
      'challenge_platinum' => AppIcons.medal,
      _ => AppIcons.medal,
    };

    final color = switch (achievement.achievementType) {
      'level_milestone' => palette.accent,
      'challenge_platinum' => palette.primary,
      _ => palette.primary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: palette.cardHigh,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            achievement.title,
            style: AppTextStyles.labelMedium.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentAchievementsSkeleton extends StatelessWidget {
  const _RecentAchievementsSkeleton();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Shimmer(
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 140,
                  height: 16,
                  decoration: BoxDecoration(
                    color: palette.cardHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  width: 60,
                  height: 14,
                  decoration: BoxDecoration(
                    color: palette.cardHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: List.generate(
                2,
                (index) => Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Container(
                    width: 100,
                    height: 28,
                    decoration: BoxDecoration(
                      color: palette.cardHigh,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
