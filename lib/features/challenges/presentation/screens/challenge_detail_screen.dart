import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/core/router/auth_guard.dart';
import 'package:doon_walkers/core/widgets/section_title.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_progress.dart';
import 'package:doon_walkers/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/challenge_admin_actions.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/challenge_icon.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/tier_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Full challenge view — description, the metric's plain-language "how this
/// is computed" explanation, and all 4 tiers with the user's current
/// position marked.
///
/// Redesign Phase 4 restyles this onto the design system. The explanation
/// *content* (metric/time-window/footnote strings), the tier
/// reached/current logic, and the sign-in gating are all unchanged.
class ChallengeDetailScreen extends ConsumerWidget {
  const ChallengeDetailScreen({super.key, required this.challengeId});

  final String challengeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengeAsync = ref.watch(challengeByIdProvider(challengeId));
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Challenge'),
        actions: [
          challengeAsync.maybeWhen(
            data: (challenge) => isAdmin && challenge != null
                ? ChallengeAdminActions(challenge: challenge)
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        child: challengeAsync.when(
          loading: () => const _ChallengeDetailSkeleton(),
          error: (error, stack) {
            debugPrint('ChallengeDetailScreen: failed to load challenge $challengeId: $error');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppIcon(AppIcons.error, size: 44, color: AppColors.danger),
                    const SizedBox(height: AppSpacing.md),
                    Text('Could not load this challenge.', style: AppTextStyles.titleMedium, textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.xl),
                    PremiumButton(
                      label: 'Retry',
                      icon: AppIcons.refresh,
                      variant: PremiumButtonVariant.glass,
                      size: PremiumButtonSize.small,
                      onPressed: () => ref.invalidate(challengeByIdProvider(challengeId)),
                    ),
                  ],
                ),
              ),
            );
          },
          data: (challenge) {
            if (challenge == null) {
              return Center(
                child: Text('Challenge not found.', style: AppTextStyles.titleMedium),
              );
            }
            return _ChallengeDetailBody(challenge: challenge);
          },
        ),
      ),
    );
  }
}

class _ChallengeDetailBody extends ConsumerWidget {
  const _ChallengeDetailBody({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(isSignedInProvider);
    final progressAsync = ref.watch(myChallengeProgressProvider);

    ChallengeProgress? myProgress;
    for (final p in progressAsync.valueOrNull ?? const <ChallengeProgress>[]) {
      if (p.challengeId == challenge.id) {
        myProgress = p;
        break;
      }
    }
    final currentTier = myProgress?.currentTier;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AppHero(
                    tag: AppHeroTags.challengeBadge(challenge.id),
                    fromRadius: AppRadius.pill,
                    toRadius: AppRadius.pill,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        gradient: AppGradients.primary,
                        shape: BoxShape.circle,
                      ),
                      child: AppIcon(ChallengeIcon.forKey(challenge.icon), size: 28, color: AppColors.onPrimary),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Text(challenge.title, style: AppTextStyles.headlineSmall),
                  ),
                ],
              ),
              if (!challenge.isActive) ...[
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      'Draft — not visible to members yet',
                      style: AppTextStyles.tinted(AppTextStyles.labelMedium, AppColors.gold),
                    ),
                  ),
                ),
              ],
              if (challenge.description.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                Text(challenge.description.trim(), style: AppTextStyles.secondary(AppTextStyles.bodyLarge)),
              ],
              const SizedBox(height: AppSpacing.xxl),
              _HowMeasured(challenge: challenge),
              const SizedBox(height: AppSpacing.xxl),
              const SectionTitle(title: 'Tiers', icon: AppIcons.medal, accent: AppColors.gold),
              const SizedBox(height: AppSpacing.md),
              if (!isSignedIn) ...[
                _SignInForProgressBanner(challenge: challenge),
                const SizedBox(height: AppSpacing.md),
              ],
              for (final threshold in challenge.tiersAscending)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _TierRow(
                    tier: threshold.tier,
                    thresholdLabel: challenge.metric.formatValue(threshold.thresholdValue),
                    isCurrent: isSignedIn && currentTier == threshold.tier,
                    isReached: isSignedIn &&
                        currentTier != null &&
                        ChallengeTier.values.indexOf(threshold.tier) <=
                            ChallengeTier.values.indexOf(currentTier),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              // Draft challenges have no meaningful leaderboard yet —
              // get_challenge_leaderboard() only ever scores active
              // challenges anyway, so hiding the entry point here avoids a
              // confusing always-empty screen.
              if (challenge.isActive)
                PremiumButton(
                  label: 'View Leaderboard',
                  icon: AppIcons.leaderboard,
                  variant: PremiumButtonVariant.secondary,
                  fullWidth: true,
                  onPressed: () => context.push(AppConstants.challengeLeaderboardLocation(challenge.id)),
                ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "How this is measured" explanation block — content unchanged.
class _HowMeasured extends StatelessWidget {
  const _HowMeasured({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blurEnabled: false,
      glowColor: AppColors.secondary,
      glowOpacity: 0.1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIcon(AppIcons.info, size: 18, color: AppColors.secondary),
              const SizedBox(width: AppSpacing.sm),
              Text('How this is measured', style: AppTextStyles.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(challenge.metric.explanation, style: AppTextStyles.bodyMedium),
          if (challenge.metric != ChallengeMetric.activeStreakDays) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(_timeWindowExplanation(challenge), style: AppTextStyles.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(challenge.metric.footnote, style: AppTextStyles.secondary(AppTextStyles.bodySmall)),
        ],
      ),
    );
  }

  String _timeWindowExplanation(Challenge challenge) {
    final base = challenge.timeWindow.explanation;
    if (challenge.timeWindow == ChallengeTimeWindow.customRange &&
        challenge.startDate != null &&
        challenge.endDate != null) {
      return '$base (${_formatDate(challenge.startDate!)} – ${_formatDate(challenge.endDate!)})';
    }
    return base;
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _SignInForProgressBanner extends StatelessWidget {
  const _SignInForProgressBanner({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blurEnabled: false,
      glowColor: AppColors.primary,
      glowOpacity: 0.16,
      onTap: () => AuthGuard.requireAuth(
        context,
        returnPath: AppConstants.challengeDetailLocation(challenge.id),
        onAuthenticated: () {},
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          const AppIcon(AppIcons.lock, size: 18, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              "Sign in to see which tier you've reached.",
              style: AppTextStyles.tinted(AppTextStyles.labelMedium, AppColors.primary),
            ),
          ),
          const AppIcon(AppIcons.chevronRight, size: 18, color: AppColors.primary),
        ],
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  const _TierRow({
    required this.tier,
    required this.thresholdLabel,
    required this.isCurrent,
    required this.isReached,
  });

  final ChallengeTier tier;
  final String thresholdLabel;
  final bool isCurrent;
  final bool isReached;

  @override
  Widget build(BuildContext context) {
    final tierColor = TierBadge.colorFor(tier);
    return GlassCard(
      blurEnabled: false,
      glowColor: isCurrent ? tierColor : null,
      glowOpacity: 0.2,
      borderColor: isCurrent ? tierColor.withValues(alpha: 0.5) : null,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          TierBadgeIcon(tier: tier, size: 44, locked: !isReached, glow: isCurrent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tier.label,
                  style: isReached
                      ? AppTextStyles.titleSmall
                      : AppTextStyles.disabled(AppTextStyles.titleSmall),
                ),
                Text('Reach $thresholdLabel', style: AppTextStyles.secondary(AppTextStyles.bodySmall)),
              ],
            ),
          ),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
              decoration: BoxDecoration(
                color: tierColor,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: AppShadows.glow(tierColor, opacity: 0.5, radius: 10),
              ),
              child: Text(
                'You are here',
                style: AppTextStyles.tinted(AppTextStyles.labelSmall, AppColors.background),
              ),
            )
          else if (isReached)
            AppIcon(AppIcons.checkCircle, color: tierColor),
        ],
      ),
    );
  }
}

/// Skeleton for the challenge detail while it loads.
class _ChallengeDetailSkeleton extends StatelessWidget {
  const _ChallengeDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: const [
          Row(
            children: [
              SkeletonCircle(size: 56),
              SizedBox(width: AppSpacing.lg),
              Expanded(child: SkeletonBox(width: 180, height: 24)),
            ],
          ),
          SizedBox(height: AppSpacing.xl),
          SkeletonText(lines: 3),
          SizedBox(height: AppSpacing.xxl),
          SkeletonBox(height: 96, borderRadius: AppRadius.card),
          SizedBox(height: AppSpacing.xxl),
          SkeletonBox(width: 120, height: 20),
          SizedBox(height: AppSpacing.md),
          SkeletonBox(height: 68, borderRadius: AppRadius.card),
          SizedBox(height: AppSpacing.md),
          SkeletonBox(height: 68, borderRadius: AppRadius.card),
        ],
      ),
    );
  }
}
