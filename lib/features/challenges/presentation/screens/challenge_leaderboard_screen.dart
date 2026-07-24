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
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Leaderboard')),
        body: const _LeaderboardSkeleton(),
      ),
      error: (error, stack) {
        debugPrint('ChallengeLeaderboardScreen: failed to load challenge $challengeId: $error');
        return Scaffold(
          appBar: AppBar(title: const Text('Leaderboard')),
          body: _LeaderboardError(onRetry: () => ref.invalidate(challengeByIdProvider(challengeId))),
        );
      },
      data: (challenge) {
        if (challenge == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Leaderboard')),
            body: Center(child: Text('Challenge not found.', style: AppTextStyles.titleMedium)),
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
    final leaderboardAsync = ref.watch(challengeLeaderboardProvider(challenge.id));

    return Scaffold(
      appBar: AppBar(title: Text('${challenge.title} — Leaderboard')),
      body: SafeArea(
        child: leaderboardAsync.when(
          loading: () => const _LeaderboardSkeleton(),
          error: (error, stack) {
            debugPrint('ChallengeLeaderboardScreen: failed to load leaderboard: $error');
            return _LeaderboardError(onRetry: () => ref.invalidate(challengeLeaderboardProvider(challenge.id)));
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
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) => AppReveal(
                index: index.clamp(0, 8),
                child: _LeaderboardRow(entry: entries[index], challenge: challenge),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Rank-badge colours for the podium — gold/silver/bronze, matching the
/// tier palette's top three, then a neutral grey for everyone else.
Color _rankColor(int rank) => switch (rank) {
  1 => AppColors.gold,
  2 => const Color(0xFFB8C2CC),
  3 => const Color(0xFFC87941),
  _ => AppColors.textSecondary,
};

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry, required this.challenge});

  final LeaderboardEntry entry;
  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final isTopThree = entry.rank <= 3;
    final rankColor = _rankColor(entry.rank);

    return GlassCard(
      blurEnabled: false,
      glowColor: isTopThree ? rankColor : null,
      glowOpacity: 0.16,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: rankColor.withValues(alpha: isTopThree ? 0.18 : 0.1),
              border: Border.all(color: rankColor.withValues(alpha: isTopThree ? 0.5 : 0.25)),
            ),
            child: isTopThree
                ? AppIcon(AppIcons.medal, size: 20, color: rankColor)
                : Text('${entry.rank}', style: AppTextStyles.tinted(AppTextStyles.titleSmall, rankColor)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Row(
              children: [
                if (isTopThree)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: Text('#${entry.rank}', style: AppTextStyles.tinted(AppTextStyles.titleSmall, rankColor)),
                  ),
                Expanded(
                  child: Text(
                    entry.displayName,
                    style: AppTextStyles.titleSmall,
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
            style: AppTextStyles.tinted(AppTextStyles.statSmall, isTopThree ? rankColor : AppColors.textPrimary),
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
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
            ),
            child: const AppIcon(AppIcons.leaderboard, size: 48, color: AppColors.secondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('No one has made progress here yet', style: AppTextStyles.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Be the first to attend a trek toward this challenge.',
            style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
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
            const AppIcon(AppIcons.error, size: 44, color: AppColors.danger),
            const SizedBox(height: AppSpacing.md),
            Text('Could not load the leaderboard.', style: AppTextStyles.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xl),
            PremiumButton(
              label: 'Retry',
              icon: AppIcons.refresh,
              variant: PremiumButtonVariant.glass,
              size: PremiumButtonSize.small,
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
    return Shimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: 6,
        separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) => Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.glassBorder),
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
