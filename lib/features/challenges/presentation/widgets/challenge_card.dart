import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/core/router/auth_guard.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_progress.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/challenge_icon.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/challenge_progress_bar.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/tier_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Card summary for a challenge on the Challenges tab — icon, title, short
/// description, current-tier badge, and a progress bar (or a sign-in
/// prompt for guests). The same card serves every role, mirroring
/// TrekCard: [adminActions] is the only role-dependent part.
///
/// Redesign Phase 4 rebuilds it on the design system. The role/state
/// branching is unchanged: draft copy for an inactive challenge, a
/// sign-in prompt for a guest, the progress bar for a signed-in member,
/// the tier badge only when a tier is actually held, and the admin slot
/// only when passed.
class ChallengeCard extends ConsumerWidget {
  const ChallengeCard({
    super.key,
    required this.challenge,
    required this.progress,
    required this.onTap,
    this.adminActions,
  });

  final Challenge challenge;

  /// Null when the signed-in user has no progress row yet, or when viewing
  /// as a guest (in which case [ChallengeProgressBar] never renders anyway).
  final ChallengeProgress? progress;

  final VoidCallback onTap;
  final Widget? adminActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(isSignedInProvider);
    final currentTier = progress?.currentTier;

    return GlassCard(
      onTap: onTap,
      blurEnabled: false,
      glowColor: currentTier != null ? TierBadge.colorFor(currentTier) : null,
      glowOpacity: 0.16,
      padding: const EdgeInsets.all(AppSpacing.lg),
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
                      style: AppTextStyles.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (challenge.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        challenge.description.trim(),
                        style: AppTextStyles.secondary(AppTextStyles.bodySmall),
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
                TierBadgeIcon(tier: currentTier, size: 34, glow: true),
              ],
              if (adminActions != null) adminActions!,
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (!challenge.isActive)
            Text(
              'Not visible to members yet.',
              style: AppTextStyles.disabled(AppTextStyles.bodySmall),
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
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        gradient: AppGradients.primary,
        shape: BoxShape.circle,
      ),
      child: AppIcon(ChallengeIcon.forKey(iconKey), color: AppColors.onPrimary, size: 22),
    );
  }
}

class _DraftPill extends StatelessWidget {
  const _DraftPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Text('Draft', style: AppTextStyles.tinted(AppTextStyles.labelSmall, AppColors.gold)),
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Row(
        children: [
          const AppIcon(AppIcons.lock, size: 16, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Sign in to track your progress',
            style: AppTextStyles.tinted(AppTextStyles.labelMedium, AppColors.primary),
          ),
        ],
      ),
    );
  }
}
