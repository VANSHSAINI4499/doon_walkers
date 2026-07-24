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
                style: AppTextStyles.tinted(AppTextStyles.labelMedium, platinum),
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
    final nextColor = TierBadge.colorFor(next.tier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProgressTrack(fraction: fraction, color: nextColor),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            AppIcon(TierBadge.icon, size: 13, color: nextColor),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                '${challenge.metric.formatValue(currentValue)} / '
                '${challenge.metric.formatValue(nextThreshold)} to ${next.tier.label}',
                style: AppTextStyles.secondary(AppTextStyles.bodySmall),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A rounded track whose fill animates up to [fraction] in [color], with a
/// soft glow on the filled portion.
class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        height: 8,
        color: AppColors.cardHigh,
        child: Align(
          alignment: Alignment.centerLeft,
          child: LayoutBuilder(
            builder: (context, constraints) => TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
              duration: AppMotion.slow,
              curve: AppMotion.emphasized,
              builder: (context, value, _) => Container(
                width: constraints.maxWidth * value,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.7), color],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: AppShadows.glow(color, opacity: 0.5, radius: 8),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
