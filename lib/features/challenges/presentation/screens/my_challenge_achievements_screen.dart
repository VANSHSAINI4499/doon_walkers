import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_tier_achievement.dart';
import 'package:doon_walkers/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/challenge_icon.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/tier_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Personal Challenge History (Version 2, Phase C2, item 5) — every
/// tier the signed-in user has reached, across every challenge, most
/// recent first, with the real date each was reached.
///
/// Lives on its own route under the Challenges tab (reached via its
/// AppBar trophy icon) rather than inline on Profile: Profile already
/// carries five sections (loyalty badge, stats, registrations,
/// wishlist, inquiries) plus two admin cards, and this is thematically
/// a Challenges concern, not a Profile one — now that Challenges has
/// its own tab with room to grow, that's the more natural home. Router-
/// level guarded (see AppConstants.routeChallengeHistory's doc): a
/// guest never reaches this screen at all.
class MyChallengeAchievementsScreen extends ConsumerWidget {
  const MyChallengeAchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final historyAsync = ref.watch(myTierHistoryProvider);
    final challengesAsync = ref.watch(activeChallengesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Achievements')),
      body: SafeArea(
        child: historyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) {
            debugPrint('MyChallengeAchievementsScreen: failed to load history: $error');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 40, color: theme.colorScheme.error),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load your achievements.',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(myTierHistoryProvider),
                      child: const Text('Retry'),
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
              padding: const EdgeInsets.all(16),
              itemCount: sorted.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final achievement = sorted[index];
                return _AchievementTile(
                  achievement: achievement,
                  challenge: challengeFor(achievement.challengeId),
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.military_tech_outlined, size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'No tiers reached yet',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Attend a trek and check back — your progress builds automatically.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            TierBadgeIcon(tier: achievement.tier, size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${achievement.tier.label} — ${challenge?.title ?? 'Challenge'}',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Reached ${_formatDate(achievement.achievedAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (challenge != null)
              Icon(ChallengeIcon.forKey(challenge!.icon), color: theme.colorScheme.outline),
          ],
        ),
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
