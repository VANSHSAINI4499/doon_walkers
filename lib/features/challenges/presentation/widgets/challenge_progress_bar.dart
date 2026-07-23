import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_progress.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/tier_badge.dart';
import 'package:flutter/material.dart';

/// The current value vs. the NEXT tier's threshold — or a "max tier
/// reached" state once platinum is cleared. Entirely generic over
/// [challenge]/[progress]: works for any metric/tier-set with no
/// special-casing, since it only ever reads [Challenge.tiersAscending]
/// and does index arithmetic, never a hardcoded threshold.
class ChallengeProgressBar extends StatelessWidget {
  const ChallengeProgressBar({super.key, required this.challenge, required this.progress});

  final Challenge challenge;

  /// Null means "no progress row yet" (e.g. a brand-new active
  /// challenge the user hasn't attended anything toward) — treated the
  /// same as a real 0-value/no-tier row, not an error/loading state.
  final ChallengeProgress? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tiers = challenge.tiersAscending;
    if (tiers.isEmpty) return const SizedBox.shrink();

    final currentValue = progress?.currentValue ?? 0;
    final currentTier = progress?.currentTier;
    final currentTierIndex = currentTier == null
        ? -1
        : tiers.indexWhere((t) => t.tier == currentTier);
    final isMaxTier = currentTierIndex == tiers.length - 1;

    if (isMaxTier) {
      return Row(
        children: [
          Icon(Icons.emoji_events_rounded, size: 18, color: TierBadge.colorFor(ChallengeTier.platinum)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Platinum reached — the top tier!',
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    }

    final next = tiers[currentTierIndex + 1];
    final prevThreshold = currentTierIndex == -1 ? 0.0 : tiers[currentTierIndex].thresholdValue;
    final nextThreshold = next.thresholdValue;
    final span = nextThreshold - prevThreshold;
    final fraction = span <= 0 ? 0.0 : ((currentValue - prevThreshold) / span).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(TierBadge.colorFor(next.tier)),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${challenge.metric.formatValue(currentValue)} / '
          '${challenge.metric.formatValue(nextThreshold)} to ${next.tier.label}',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
