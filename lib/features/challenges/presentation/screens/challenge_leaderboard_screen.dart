import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/domain/entities/leaderboard_entry.dart';
import 'package:doon_walkers/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Leaderboard for ONE challenge (Version 2, Phase C3) — reached from
/// that challenge's own Detail screen ("View Leaderboard"), not a
/// separate tab-level destination: a leaderboard only ever makes sense
/// in the context of one specific challenge/metric (see
/// 0025_leaderboard.sql's doc for why there's no cross-challenge
/// "overall" ranking), so a standalone tab would just need its own
/// challenge picker — duplicating the list ChallengesScreen already
/// shows. Public/read-only for guests, same as the rest of the
/// Challenges tab; nothing here requires sign-in.
class ChallengeLeaderboardScreen extends ConsumerWidget {
  const ChallengeLeaderboardScreen({super.key, required this.challengeId});

  final String challengeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final challengeAsync = ref.watch(challengeByIdProvider(challengeId));

    return challengeAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Leaderboard')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) {
        debugPrint('ChallengeLeaderboardScreen: failed to load challenge $challengeId: $error');
        return Scaffold(
          appBar: AppBar(title: const Text('Leaderboard')),
          body: Center(
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
          ),
        );
      },
      data: (challenge) {
        if (challenge == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Leaderboard')),
            body: const Center(child: Text('Challenge not found.')),
          );
        }
        return _LeaderboardBody(challenge: challenge);
      },
    );
  }
}

class _LeaderboardBody extends ConsumerWidget {
  const _LeaderboardBody({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final leaderboardAsync = ref.watch(challengeLeaderboardProvider(challenge.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('${challenge.title} — Leaderboard'),
      ),
      body: SafeArea(
        child: leaderboardAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) {
            debugPrint('ChallengeLeaderboardScreen: failed to load leaderboard: $error');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 40, color: theme.colorScheme.error),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load the leaderboard.',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(challengeLeaderboardProvider(challenge.id)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          },
          data: (entries) {
            if (entries.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [_EmptyLeaderboard()],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _LeaderboardRow(
                entry: entries[index],
                challenge: challenge,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyLeaderboard extends StatelessWidget {
  const _EmptyLeaderboard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.leaderboard_outlined, size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'No one has made progress here yet',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to attend a trek toward this challenge.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry, required this.challenge});

  final LeaderboardEntry entry;
  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTopThree = entry.rank <= 3;

    return Card(
      elevation: isTopThree ? 2 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '#${entry.rank}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isTopThree ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.displayName,
                style: theme.textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              challenge.metric.formatValue(entry.score),
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
