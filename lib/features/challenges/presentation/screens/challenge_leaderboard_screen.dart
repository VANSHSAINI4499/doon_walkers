import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/domain/entities/leaderboard_entry.dart';
import 'package:doon_walkers/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Leaderboard for ONE challenge — reached from that challenge's own Detail
/// screen ("View Leaderboard"). Public/read-only for guests, same as the
/// rest of the Challenges tab.
///
/// Redesign Phase 4 restyles the ranked list onto the design system.
/// **The data contract is untouched:** each row still shows only
/// [LeaderboardEntry.displayName]/[LeaderboardEntry.rank]/
/// [LeaderboardEntry.score] — the RPC never returns more (and excludes
/// opted-out users server-side), so this pass cannot expose more per-user
/// data than it already did.
class ChallengeLeaderboardScreen extends ConsumerWidget {
  const ChallengeLeaderboardScreen({super.key, required this.challengeId});

  final String challengeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengeAsync = ref.watch(challengeByIdProvider(challengeId));

    return challengeAsync.when(
      loading:
          () => Scaffold(
            appBar: AppBar(title: const Text('Leaderboard')),
            body: const _LeaderboardSkeleton(),
          ),
      error: (error, stack) {
        debugPrint(
          'ChallengeLeaderboardScreen: failed to load challenge $challengeId: $error',
        );
        return Scaffold(
          appBar: AppBar(title: const Text('Leaderboard')),
          body: _LeaderboardError(
            onRetry: () => ref.invalidate(challengeByIdProvider(challengeId)),
          ),
        );
      },
      data: (challenge) {
        if (challenge == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Leaderboard')),
            body: Center(
              child: Text(
                'Challenge not found.',
                style: AppTextStyles.titleMedium,
              ),
            ),
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
    final leaderboardAsync = ref.watch(
      challengeLeaderboardProvider(challenge.id),
    );

    return Scaffold(
      appBar: AppBar(title: Text('${challenge.title} — Leaderboard')),
      body: SafeArea(
        child: leaderboardAsync.when(
          loading: () => const _LeaderboardSkeleton(),
          error: (error, stack) {
            debugPrint(
              'ChallengeLeaderboardScreen: failed to load leaderboard: $error',
            );
            return _LeaderboardError(
              onRetry:
                  () => ref.invalidate(
                    challengeLeaderboardProvider(challenge.id),
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
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: entries.length,
              separatorBuilder:
                  (context, index) => const SizedBox(height: AppSpacing.md),
              itemBuilder:
                  (context, index) => AppReveal(
                    index: index.clamp(0, 8),
                    child: _LeaderboardRow(
                      entry: entries[index],
                      challenge: challenge,
                    ),
                  ),
            );
          },
        ),
      ),
    );
  }
}

/// Rank-badge colours for the podium — the design system's achievement
/// metals, then neutral ink for everyone else.
///
/// Reads from the palette rather than the hardcoded hexes places 2 and 3
/// used to be, so the podium stays consistent with tier badges and works
/// in both themes.
Color _rankColor(AppPalette palette, int rank) => switch (rank) {
  1 => palette.gold,
  2 => palette.silver,
  3 => palette.bronze,
  _ => palette.textSecondary,
};

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry, required this.challenge});

  final LeaderboardEntry entry;
  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final isTopThree = entry.rank <= 3;
    final rankColor = _rankColor(palette, entry.rank);

    return AppCard(
      borderColor: isTopThree ? rankColor.withValues(alpha: 0.5) : null,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: rankColor.withValues(alpha: isTopThree ? 0.18 : 0.1),
              border: Border.all(
                color: rankColor.withValues(alpha: isTopThree ? 0.5 : 0.25),
              ),
            ),
            child:
                isTopThree
                    ? AppIcon(AppIcons.medal, size: 20, color: rankColor)
                    : Text(
                      '${entry.rank}',
                      style: AppTextStyles.titleSmall.copyWith(
                        color: rankColor,
                      ),
                    ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Row(
              children: [
                if (isTopThree)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: Text(
                      '#${entry.rank}',
                      style: AppTextStyles.titleSmall.copyWith(
                        color: rankColor,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    entry.displayName,
                    style: AppTextStyles.titleSmall.copyWith(
                      color: palette.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            challenge.metric.formatValue(entry.score),
            style: AppTextStyles.statSmall.copyWith(
              color: isTopThree ? rankColor : palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLeaderboard extends StatelessWidget {
  const _EmptyLeaderboard();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: palette.cardHigh,
              shape: BoxShape.circle,
            ),
            child: AppIcon(
              AppIcons.leaderboard,
              size: 32,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'No one has made progress here yet',
            style: AppTextStyles.titleMedium.copyWith(
              color: palette.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Be the first to make progress toward this challenge.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: palette.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LeaderboardError extends StatelessWidget {
  const _LeaderboardError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
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
              'Could not load the leaderboard.',
              style: AppTextStyles.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Retry',
              icon: AppIcons.refresh,
              variant: AppButtonVariant.glass,
              size: AppButtonSize.small,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardSkeleton extends StatelessWidget {
  const _LeaderboardSkeleton();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Shimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: 6,
        separatorBuilder:
            (context, index) => const SizedBox(height: AppSpacing.md),
        itemBuilder:
            (context, index) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: palette.border),
              ),
              child: const Row(
                children: [
                  SkeletonCircle(size: 40),
                  SizedBox(width: AppSpacing.md),
                  Expanded(child: SkeletonBox(height: 14)),
                  SizedBox(width: AppSpacing.md),
                  SkeletonBox(width: 60, height: 16),
                ],
              ),
            ),
      ),
    );
  }
}
