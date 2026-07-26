import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/core/router/auth_guard.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_progress.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/challenge_icon.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/challenge_meta_row.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/challenge_progress_bar.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/tier_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Card summary for a challenge — icon, title, short description,
/// current-tier badge, and a progress bar (or a sign-in prompt for
/// guests). One card serves every role; [adminActions] is the only
/// role-dependent part.
///
/// Redesign 2.0 Phase 12 restyles it calm: flat card, no tier-coloured
/// halo, tinted hairline instead when a tier is held. **The role/state
/// branching is unchanged** and pinned by challenge_card_test.dart: draft
/// copy for an inactive challenge, a sign-in prompt for a guest, the
/// progress bar for a signed-in member, the tier badge only when a tier
/// is actually held.
///
/// ## Points and participant count are real (Phase 21/23)
///
/// This doc used to say neither existed — that was true through Phase 12,
/// but Phase 21's `0038_challenge_enrollments.sql` added opt-in enrollment,
/// `challenges.point_value`, and `get_challenge_participant_count()`, so
/// both are now real, sourced figures: [showPoints] renders
/// `challenge.pointValue` and [participantCount] (when the caller has
/// fetched one) renders the enrolled-member count. Neither is invented —
/// a caller that hasn't loaded a participant count simply passes null and
/// the chip is omitted, same discipline as the days-left chip below.
///
/// [showMeta] adds the metric/window/days-left/participant-count/points
/// row used by Explore and My Challenges, where a card has to be legible
/// without the user already knowing what the challenge measures.
class ChallengeCard extends ConsumerWidget {
  const ChallengeCard({
    super.key,
    required this.challenge,
    required this.progress,
    required this.onTap,
    this.adminActions,
    this.showMeta = false,
    this.showPoints = false,
    this.participantCount,
  });

  final Challenge challenge;

  /// Null when the signed-in user has no progress row yet, or when viewing
  /// as a guest (in which case [ChallengeProgressBar] never renders anyway).
  final ChallengeProgress? progress;

  final VoidCallback onTap;
  final Widget? adminActions;

  /// Show the metric / time-window / days-left chips.
  final bool showMeta;

  /// Show the points pill (e.g. "+50 pts") — Phase 21.
  final bool showPoints;

  /// When non-null, render a participant count chip. Phase 21.
  final int? participantCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final isSignedIn = ref.watch(isSignedInProvider);
    final currentTier = progress?.currentTier;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      // A tinted hairline is what marks a card as "you hold a tier here" —
      // the calm replacement for the tier-coloured glow this card used to
      // cast.
      borderColor: currentTier != null
          ? TierBadge.colorFor(currentTier).withValues(alpha: 0.5)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppHero(
                tag: AppHeroTags.challengeBadge(challenge.id),
                fromRadius: AppRadius.pill,
                toRadius: AppRadius.pill,
                child: _ChallengeAvatar(iconKey: challenge.icon),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.title,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: palette.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (challenge.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        challenge.description.trim(),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: palette.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (!challenge.isActive) ...[
                const SizedBox(width: AppSpacing.sm),
                const _DraftPill(),
              ],
              if (currentTier != null) ...[
                const SizedBox(width: AppSpacing.sm),
                TierBadgeIcon(tier: currentTier, size: 32),
              ],
              if (adminActions != null) adminActions!,
            ],
          ),
          if (showMeta) ...[
            const SizedBox(height: AppSpacing.md),
            ChallengeMetaRow(
              challenge: challenge,
              participantCount: participantCount,
              pointValue: showPoints ? challenge.pointValue : null,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (!challenge.isActive)
            Text(
              'Not visible to members yet.',
              style: AppTextStyles.bodySmall.copyWith(
                color: palette.textDisabled,
              ),
            )
          else if (!isSignedIn)
            _SignInPrompt(onTap: () => _bounceToSignIn(context))
          else
            ChallengeProgressBar(challenge: challenge, progress: progress),
        ],
      ),
    );
  }

  void _bounceToSignIn(BuildContext context) {
    AuthGuard.requireAuth(
      context,
      returnPath: AppConstants.routeChallenges,
      onAuthenticated: () {},
    );
  }
}

class _ChallengeAvatar extends StatelessWidget {
  const _ChallengeAvatar({required this.iconKey});

  final String? iconKey;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: palette.primarySubtle,
        shape: BoxShape.circle,
      ),
      child: AppIcon(
        ChallengeIcon.forKey(iconKey),
        color: palette.primary,
        size: 20,
      ),
    );
  }
}

class _DraftPill extends StatelessWidget {
  const _DraftPill();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: palette.accentContainer,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        'Draft',
        style: AppTextStyles.labelSmall.copyWith(color: palette.accent),
      ),
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Row(
        children: [
          AppIcon(AppIcons.lock, size: 16, color: palette.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Sign in to track your progress',
            style: AppTextStyles.labelMedium.copyWith(color: palette.primary),
          ),
        ],
      ),
    );
  }
}
