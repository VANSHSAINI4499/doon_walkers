import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/core/router/auth_guard.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_progress.dart';
import 'package:doon_walkers/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/challenge_admin_actions.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/challenge_icon.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/challenge_meta_row.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/join_challenge_button.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/tier_badge.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/top_participants_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Full challenge view — description, participant count + point value,
/// Join/Leave, the metric's plain-language "how this is computed"
/// explanation, all 4 tiers with the user's current position marked, and
/// (Phase 23) a Top Participants preview.
///
/// Redesign Phase 4 restyles this onto the design system. The explanation
/// *content* (metric/time-window/footnote strings), the tier
/// reached/current logic, and the sign-in gating are all unchanged.
///
/// ## Phase 23: finishing Phase 21's unconsumed pieces
///
/// [JoinChallengeButton], [ChallengeMetaRow]'s participant-count/points
/// chips, and [TopParticipantsSection] all existed as working
/// widgets/providers/RPCs before this phase — nothing on this screen
/// called any of them. This phase wires them in; it does not change what
/// they compute.
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
                    AppIcon(
                      AppIcons.error,
                      size: 40,
                      color: AppPalette.of(context).danger,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Could not load this challenge.',
                      style: AppTextStyles.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: 'Retry',
                      icon: AppIcons.refresh,
                      variant: AppButtonVariant.glass,
                      size: AppButtonSize.small,
                      onPressed: () =>
                          ref.invalidate(challengeByIdProvider(challengeId)),
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
    final palette = AppPalette.of(context);
    final isSignedIn = ref.watch(isSignedInProvider);
    final progressAsync = ref.watch(myChallengeProgressProvider);
    final participantCount = challenge.isActive
        ? ref.watch(challengeParticipantCountProvider(challenge.id)).valueOrNull
        : null;

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
                      decoration: BoxDecoration(
                        color: palette.primarySubtle,
                        shape: BoxShape.circle,
                      ),
                      child: AppIcon(
                        ChallengeIcon.forKey(challenge.icon),
                        size: 26,
                        color: palette.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Text(
                      challenge.title,
                      style: AppTextStyles.headlineSmall.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
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
                      color: palette.accentContainer,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      'Draft — not visible to members yet',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: palette.accent,
                      ),
                    ),
                  ),
                ),
              ],
              // Phase 24: real enrollment count, not a fabricated
              // threshold — see kPopularChallengeThreshold's doc.
              if (participantCount != null &&
                  participantCount >= kPopularChallengeThreshold) ...[
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                    decoration: BoxDecoration(
                      color: palette.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIcon(AppIcons.trending, size: 14, color: palette.gold),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Popular Challenge',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: palette.gold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (challenge.description.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                Text(
                  challenge.description.trim(),
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              ChallengeMetaRow(
                challenge: challenge,
                participantCount: participantCount,
                pointValue: challenge.pointValue,
              ),
              if (challenge.isActive && isSignedIn) ...[
                const SizedBox(height: AppSpacing.lg),
                JoinChallengeButton(challenge: challenge),
              ],
              const SizedBox(height: AppSpacing.xxl),
              _HowMeasured(challenge: challenge),
              const SizedBox(height: AppSpacing.xxl),
              Row(
                children: [
                  AppIcon(AppIcons.medal, size: 18, color: palette.textSecondary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Tiers',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                ],
              ),
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
                AppButton(
                  label: 'View Leaderboard',
                  icon: AppIcons.leaderboard,
                  variant: AppButtonVariant.glass,
                  fullWidth: true,
                  onPressed: () => context.push(
                    AppConstants.challengeLeaderboardLocation(challenge.id),
                  ),
                ),
              // Same gating as the leaderboard button just above — a
              // draft challenge has no enrollments to show yet.
              if (challenge.isActive) ...[
                const SizedBox(height: AppSpacing.xxl),
                TopParticipantsSection(challenge: challenge),
              ],
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
    final palette = AppPalette.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(AppIcons.info, size: 18, color: palette.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'How this is measured',
                style: AppTextStyles.titleSmall.copyWith(
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            challenge.metric.explanation,
            style: AppTextStyles.bodyMedium.copyWith(
              color: palette.textPrimary,
            ),
          ),
          if (challenge.metric != ChallengeMetric.activeStreakDays) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              _timeWindowExplanation(challenge),
              style: AppTextStyles.bodyMedium.copyWith(
                color: palette.textPrimary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            challenge.metric.footnote,
            style: AppTextStyles.bodySmall.copyWith(
              color: palette.textSecondary,
            ),
          ),
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
    final palette = AppPalette.of(context);
    return AppCard(
      borderColor: palette.primary.withValues(alpha: 0.45),
      onTap: () => AuthGuard.requireAuth(
        context,
        returnPath: AppConstants.challengeDetailLocation(challenge.id),
        onAuthenticated: () {},
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          AppIcon(AppIcons.lock, size: 18, color: palette.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              "Sign in to see which tier you've reached.",
              style: AppTextStyles.labelMedium.copyWith(color: palette.primary),
            ),
          ),
          AppIcon(AppIcons.chevronRight, size: 18, color: palette.primary),
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
    final palette = AppPalette.of(context);
    final tierColor = TierBadge.colorFor(tier);
    return AppCard(
      borderColor: isCurrent ? tierColor.withValues(alpha: 0.6) : null,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          TierBadgeIcon(tier: tier, size: 40, locked: !isReached),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tier.label,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: isReached
                        ? palette.textPrimary
                        : palette.textDisabled,
                  ),
                ),
                Text(
                  'Reach $thresholdLabel',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: tierColor,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                'You are here',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.charcoal,
                ),
              ),
            )
          else if (isReached)
            AppIcon(AppIcons.checkCircle, size: 20, color: tierColor),
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
