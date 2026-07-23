import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/core/router/auth_guard.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_progress.dart';
import 'package:doon_walkers/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/challenge_admin_actions.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/challenge_icon.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/tier_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Full challenge view — description, the metric's plain-language "how
/// this is computed" explanation, and all 4 tiers with the user's
/// current position marked (Version 2, Phase C2, item 4).
class ChallengeDetailScreen extends ConsumerWidget {
  const ChallengeDetailScreen({super.key, required this.challengeId});

  final String challengeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final challengeAsync = ref.watch(challengeByIdProvider(challengeId));
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Challenge'),
        actions: [
          challengeAsync.maybeWhen(
            data: (challenge) =>
                isAdmin && challenge != null ? ChallengeAdminActions(challenge: challenge) : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        child: challengeAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) {
            debugPrint('ChallengeDetailScreen: failed to load challenge $challengeId: $error');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 40, color: theme.colorScheme.error),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load this challenge.',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(challengeByIdProvider(challengeId)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          },
          data: (challenge) {
            if (challenge == null) {
              return const Center(child: Text('Challenge not found.'));
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
    final theme = Theme.of(context);
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
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      ChallengeIcon.forKey(challenge.icon),
                      size: 28,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      challenge.title,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              if (!challenge.isActive) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Draft — not visible to members yet',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.colorScheme.onTertiaryContainer),
                  ),
                ),
              ],
              if (challenge.description.trim().isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(challenge.description.trim(), style: theme.textTheme.bodyLarge),
              ],
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text('How this is measured', style: theme.textTheme.titleSmall),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(challenge.metric.explanation, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    if (challenge.metric != ChallengeMetric.activeStreakDays) ...[
                      Text(_timeWindowExplanation(challenge), style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      challenge.metric.footnote,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text('Tiers', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              if (!isSignedIn)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SignInForProgressBanner(challenge: challenge),
                ),
              const SizedBox(height: 8),
              for (final threshold in challenge.tiersAscending)
                _TierRow(
                  tier: threshold.tier,
                  thresholdLabel: challenge.metric.formatValue(threshold.thresholdValue),
                  isCurrent: isSignedIn && currentTier == threshold.tier,
                  isReached: isSignedIn &&
                      currentTier != null &&
                      ChallengeTier.values.indexOf(threshold.tier) <=
                          ChallengeTier.values.indexOf(currentTier),
                ),
              const SizedBox(height: 16),
              // Draft challenges have no meaningful leaderboard yet —
              // get_challenge_leaderboard() only ever scores active
              // challenges anyway (0025_leaderboard.sql), so hiding the
              // entry point here avoids a confusing always-empty screen.
              if (challenge.isActive)
                OutlinedButton.icon(
                  onPressed: () =>
                      context.push(AppConstants.challengeLeaderboardLocation(challenge.id)),
                  icon: const Icon(Icons.leaderboard_outlined),
                  label: const Text('View Leaderboard'),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
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
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => AuthGuard.requireAuth(
        context,
        returnPath: AppConstants.challengeDetailLocation(challenge.id),
        onAuthenticated: () {},
      ),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline_rounded, size: 18, color: theme.colorScheme.onPrimaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sign in to see which tier you\'ve reached.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          TierBadgeIcon(tier: tier, size: 44, locked: !isReached),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tier.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isReached ? null : theme.colorScheme.outline,
                  ),
                ),
                Text(
                  'Reach $thresholdLabel',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'You are here',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold),
              ),
            )
          else if (isReached)
            Icon(Icons.check_circle_rounded, color: TierBadge.colorFor(tier)),
        ],
      ),
    );
  }
}
