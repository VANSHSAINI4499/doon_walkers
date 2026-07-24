import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_tier_achievement.dart';
import 'package:doon_walkers/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/challenge_icon.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/tier_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Personal Challenge History — every tier the signed-in user has reached,
/// across every challenge, most recent first, with the real date each was
/// reached. Reached via the Challenges tab's app-bar trophy; router-level
/// guarded so a guest never reaches it.
///
/// Redesign Phase 4 restyles it onto the design system (glass tiles, the
/// new tier badges, a skeleton loader). The data source and ordering are
/// unchanged.
class MyChallengeAchievementsScreen extends ConsumerWidget {
  const MyChallengeAchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(myTierHistoryProvider);
    final challengesAsync = ref.watch(activeChallengesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Achievements')),
      body: SafeArea(
        child: historyAsync.when(
          loading: () => const _AchievementsSkeleton(),
          error: (error, stack) {
            debugPrint('MyChallengeAchievementsScreen: failed to load history: $error');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppIcon(AppIcons.error, size: 44, color: AppColors.danger),
                    const SizedBox(height: AppSpacing.md),
                    Text('Could not load your achievements.', style: AppTextStyles.titleMedium, textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.xl),
                    PremiumButton(
                      label: 'Retry',
                      icon: AppIcons.refresh,
                      variant: PremiumButtonVariant.glass,
                      size: PremiumButtonSize.small,
                      onPressed: () => ref.invalidate(myTierHistoryProvider),
                    ),
                  ],
                ),
              ),
            );
          },
          data: (history) {
            if (history.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [_EmptyAchievements()],
              );
            }

            final challenges = challengesAsync.valueOrNull ?? const <Challenge>[];
            Challenge? challengeFor(String id) {
              for (final c in challenges) {
                if (c.id == id) return c;
              }
              return null;
            }

            final sorted = [...history]..sort((a, b) => b.achievedAt.compareTo(a.achievedAt));

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: sorted.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final achievement = sorted[index];
                return AppReveal(
                  index: index.clamp(0, 8),
                  child: _AchievementTile(
                    achievement: achievement,
                    challenge: challengeFor(achievement.challengeId),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _EmptyAchievements extends StatelessWidget {
  const _EmptyAchievements();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
            ),
            child: const AppIcon(AppIcons.medal, size: 48, color: AppColors.gold),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('No tiers reached yet', style: AppTextStyles.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Attend a trek and check back — your progress builds automatically.',
            style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement, required this.challenge});

  final ChallengeTierAchievement achievement;
  final Challenge? challenge;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blurEnabled: false,
      glowColor: TierBadge.colorFor(achievement.tier),
      glowOpacity: 0.12,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          TierBadgeIcon(tier: achievement.tier, size: 44),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${achievement.tier.label} — ${challenge?.title ?? 'Challenge'}',
                  style: AppTextStyles.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Reached ${_formatDate(achievement.achievedAt)}',
                  style: AppTextStyles.secondary(AppTextStyles.bodySmall),
                ),
              ],
            ),
          ),
          if (challenge != null)
            AppIcon(ChallengeIcon.forKey(challenge!.icon), color: AppColors.textSecondary),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _AchievementsSkeleton extends StatelessWidget {
  const _AchievementsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: 5,
        separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) => Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: const Row(
            children: [
              SkeletonCircle(size: 44),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 180, height: 14),
                    SizedBox(height: AppSpacing.sm),
                    SkeletonBox(width: 100, height: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
