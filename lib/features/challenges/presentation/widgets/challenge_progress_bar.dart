import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_progress.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/tier_badge.dart';
import 'package:flutter/material.dart';

/// The current value vs. the NEXT tier's threshold — or a "max tier
/// reached" state once platinum is cleared.
///
/// Entirely generic over [challenge]/[progress]: it only ever reads
/// [Challenge.tiersAscending] and does index arithmetic, never a
/// hardcoded threshold. Redesign Phase 4 restyles the bar onto the design
/// system (a rounded track that fills toward the next tier's colour, and
/// an animated fill) — **the fraction/threshold maths is untouched.**
class ChallengeProgressBar extends StatelessWidget {
  const ChallengeProgressBar({super.key, required this.challenge, required this.progress});

  final Challenge challenge;

  /// Null means "no progress row yet" — treated the same as a real
  /// 0-value/no-tier row, not an error/loading state.
  final ChallengeProgress? progress;

  @override
  Widget build(BuildContext context) {
    final tiers = challenge.tiersAscending;
    if (tiers.isEmpty) return const SizedBox.shrink();

    final currentValue = progress?.currentValue ?? 0;
    final currentTier = progress?.currentTier;
    final currentTierIndex = currentTier == null
        ? -1
        : tiers.indexWhere((t) => t.tier == currentTier);
    final isMaxTier = currentTierIndex == tiers.length - 1;

    final palette = AppPalette.of(context);

    if (isMaxTier) {
      final platinum = TierBadge.colorFor(ChallengeTier.platinum);
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: platinum.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: platinum.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            AppIcon(AppIcons.celebrate, size: 18, color: platinum),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Platinum reached — the top tier!',
                style: AppTextStyles.labelMedium.copyWith(color: platinum),
              ),
            ),
          ],
        ),
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
        // The shared bar, in the single accent — not the next tier's metal
        // colour as before. A bar that changes hue as you climb made every
        // card on the list a different colour; the tier being aimed for is
        // already named in the caption right below it.
        AppProgressBar(value: fraction, height: 6),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            AppIcon(
              TierBadge.icon,
              size: 13,
              color: TierBadge.colorFor(next.tier),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                '${challenge.metric.formatValue(currentValue)} / '
                '${challenge.metric.formatValue(nextThreshold)} to ${next.tier.label}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
