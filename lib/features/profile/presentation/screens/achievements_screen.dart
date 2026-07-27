import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/activity/presentation/providers/activity_dashboard_providers.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/level_badge.dart';
import 'package:doon_walkers/features/profile/domain/loyalty_badge.dart';
import 'package:doon_walkers/features/profile/presentation/providers/points_providers.dart';
import 'package:doon_walkers/features/registrations/presentation/providers/registration_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Unlocked achievements screen — showing a summary header, a 2-column
/// category insights grid (Challenges, Milestones, Loyalty, Check-ins),
/// and the recent activity list.
///
/// Phase 25.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final summaryAsync = ref.watch(myPointsSummaryProvider);
    final statsAsync = ref.watch(myRegistrationStatsProvider);
    final achievementsAsync = ref.watch(
      myAchievementsProvider((limit: 100, offset: 0)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Achievements')),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Achievements Header
                  summaryAsync.when(
                    loading: () => const _HeaderSkeleton(),
                    error: (_, __) => const SizedBox.shrink(),
                    data:
                        (summary) => _AchievementsHeader(
                          totalPoints: summary.totalPoints,
                          level: summary.level,
                          progressToNextLevel: summary.progressToNextLevel,
                          isMaxLevel: summary.isMaxLevel,
                          nextLevel: summary.nextLevel,
                          pointsToNextLevel: summary.pointsToNextLevel,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 2. Insights Grid Header
                  Text(
                    'Category Insights',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 3. Category Grid
                  achievementsAsync.when(
                    loading: () => const _GridSkeleton(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (achievements) {
                      final platinumCount =
                          achievements
                              .where(
                                (a) =>
                                    a.achievementType == 'challenge_platinum',
                              )
                              .length;
                      final milestoneCount =
                          achievements
                              .where(
                                (a) => a.achievementType == 'level_milestone',
                              )
                              .length;

                      return statsAsync.when(
                        loading: () => const _GridSkeleton(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (stats) {
                          final attended = stats.totalAttended;
                          final hasLoyaltyBadge = attended >= 3;
                          final loyaltyBadgeName =
                              loyaltyBadgeFor(attended).name;

                          return GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: AppSpacing.md,
                            mainAxisSpacing: AppSpacing.md,
                            childAspectRatio: 1.35,
                            children: [
                              _CategoryCard(
                                icon: AppIcons.medal,
                                label: 'Challenges',
                                status:
                                    platinumCount > 0
                                        ? '$platinumCount completed'
                                        : 'Locked',
                                isLocked: platinumCount == 0,
                                accentColor: palette.primary,
                              ),
                              _CategoryCard(
                                icon: AppIcons.star,
                                label: 'Milestones',
                                status:
                                    milestoneCount > 0
                                        ? '$milestoneCount unlocked'
                                        : 'Locked',
                                isLocked: milestoneCount == 0,
                                accentColor: palette.accent,
                              ),
                              _CategoryCard(
                                icon: AppIcons.verified,
                                label: 'Loyalty Badge',
                                status:
                                    hasLoyaltyBadge
                                        ? loyaltyBadgeName
                                        : 'No badge yet',
                                isLocked: !hasLoyaltyBadge,
                                accentColor: const Color(0xFF26A69A), // Teal
                              ),
                              _CategoryCard(
                                icon: AppIcons.walk,
                                label: 'Trek Check-ins',
                                status:
                                    attended > 0
                                        ? '$attended checked in'
                                        : 'No check-ins',
                                isLocked: attended == 0,
                                accentColor: const Color(0xFFFF7043), // Orange
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // 4. Recent Activity
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Activity',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: palette.textPrimary,
                        ),
                      ),
                      TextButton(
                        onPressed:
                            () => context.push(AppConstants.routePointsHistory),
                        child: Text(
                          'View Points History',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: palette.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  achievementsAsync.when(
                    loading: () => const _ListSkeleton(),
                    error:
                        (err, __) => Text(
                          'Failed to load activity list.',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: palette.danger,
                          ),
                        ),
                    data: (achievements) {
                      if (achievements.isEmpty) {
                        return AppCard(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            children: [
                              AppIcon(
                                AppIcons.medal,
                                size: 36,
                                color: palette.textDisabled,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'No achievements yet',
                                style: AppTextStyles.titleSmall.copyWith(
                                  color: palette.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Complete a challenge or reach a new level to earn your first.',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: palette.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      final recent = achievements.take(10).toList();

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: recent.length,
                        separatorBuilder:
                            (context, index) =>
                                const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final item = recent[index];
                          return AppCard(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Row(
                              children: [
                                _ActivityIcon(
                                  type: item.achievementType,
                                  palette: palette,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: AppTextStyles.titleSmall
                                            .copyWith(
                                              color: palette.textPrimary,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.description,
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: palette.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Text(
                                  _formatRelativeDate(item.unlockedAt),
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: palette.textDisabled,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatRelativeDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }
}

class _AchievementsHeader extends StatelessWidget {
  const _AchievementsHeader({
    required this.totalPoints,
    required this.level,
    required this.progressToNextLevel,
    required this.isMaxLevel,
    this.nextLevel,
    this.pointsToNextLevel,
  });

  final int totalPoints;
  final int level;
  final double progressToNextLevel;
  final bool isMaxLevel;
  final int? nextLevel;
  final int? pointsToNextLevel;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Level Standing',
                    style: AppTextStyles.overline.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '$totalPoints',
                        style: AppTextStyles.headlineMedium.copyWith(
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'points',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              LevelBadge(level: level),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppProgressBar(
            value: progressToNextLevel,
            label:
                isMaxLevel
                    ? 'Top level reached'
                    : 'Progress to Level $nextLevel',
            trailing: isMaxLevel ? null : '$pointsToNextLevel to go',
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.icon,
    required this.label,
    required this.status,
    required this.isLocked,
    required this.accentColor,
  });

  final IconData icon;
  final String label;
  final String status;
  final bool isLocked;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final cardColor =
        isLocked ? palette.card.withValues(alpha: 0.5) : palette.card;
    final color = isLocked ? palette.textDisabled : accentColor;
    final txtColor = isLocked ? palette.textDisabled : palette.textPrimary;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color:
              isLocked ? palette.border.withValues(alpha: 0.5) : palette.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      isLocked
                          ? palette.cardHigh.withValues(alpha: 0.5)
                          : color.withValues(alpha: 0.12),
                ),
                child: AppIcon(icon, size: 16, color: color),
              ),
              if (isLocked)
                AppIcon(AppIcons.lock, size: 14, color: palette.textDisabled),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                status,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: txtColor,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityIcon extends StatelessWidget {
  const _ActivityIcon({required this.type, required this.palette});

  final String type;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      'level_milestone' => AppIcons.star,
      'challenge_platinum' => AppIcons.medal,
      _ => AppIcons.medal,
    };

    final color = switch (type) {
      'level_milestone' => palette.accent,
      'challenge_platinum' => palette.primary,
      _ => palette.primary,
    };

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: AppIcon(icon, size: 20, color: color),
    );
  }
}

// ── Skeletons ─────────────────────────────────────────────────────────────

class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Shimmer(
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 80, height: 10, color: palette.cardHigh),
                    const SizedBox(height: AppSpacing.sm),
                    Container(width: 120, height: 24, color: palette.cardHigh),
                  ],
                ),
                Container(
                  width: 60,
                  height: 24,
                  decoration: BoxDecoration(
                    color: palette.cardHigh,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              height: 8,
              color: palette.cardHigh,
            ),
          ],
        ),
      ),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Shimmer(
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.35,
        children: List.generate(
          4,
          (index) => Container(
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: palette.border),
            ),
          ),
        ),
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Shimmer(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        separatorBuilder:
            (context, index) => const SizedBox(height: AppSpacing.sm),
        itemBuilder:
            (context, index) => Container(
              height: 64,
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: palette.border),
              ),
            ),
      ),
    );
  }
}
