import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/core/router/auth_guard.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_progress.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/challenge_icon.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/challenge_progress_bar.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/tier_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Card summary for a challenge on the Challenges tab — icon, title,
/// short description, current-tier badge, and a progress bar (or a
/// sign-in prompt for guests). The same card serves every role,
/// mirroring TrekCard: [adminActions] is the only role-dependent part.
class ChallengeCard extends ConsumerWidget {
  const ChallengeCard({
    super.key,
    required this.challenge,
    required this.progress,
    required this.onTap,
    this.adminActions,
  });

  final Challenge challenge;

  /// Null when the signed-in user has no progress row yet, or when
  /// viewing as a guest (in which case [ChallengeProgressBar] never
  /// renders anyway — see build below).
  final ChallengeProgress? progress;

  final VoidCallback onTap;
  final Widget? adminActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isSignedIn = ref.watch(isSignedInProvider);

    return Card(
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      ChallengeIcon.forKey(challenge.icon),
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          challenge.title,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (challenge.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            challenge.description.trim(),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!challenge.isActive)
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Draft',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (progress?.currentTier != null) ...[
                    const SizedBox(width: 4),
                    TierBadgeIcon(tier: progress!.currentTier!, size: 32),
                  ],
                  if (adminActions != null) adminActions!,
                ],
              ),
              const SizedBox(height: 12),
              if (!challenge.isActive)
                Text(
                  'Not visible to members yet.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                )
              else if (!isSignedIn)
                _SignInPrompt(onTap: () => _bounceToSignIn(context))
              else
                ChallengeProgressBar(challenge: challenge, progress: progress),
            ],
          ),
        ),
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

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            'Sign in to track your progress',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
