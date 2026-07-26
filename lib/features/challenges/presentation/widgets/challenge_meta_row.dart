import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:flutter/material.dart';

/// The quiet metadata row under a challenge's title on Explore: what it
/// measures, over what window, and how long is left.
///
/// Explore is a browsing surface, so a card has to be legible to someone
/// who has never opened that challenge. On My Challenges the same
/// information is redundant (you already know what you're tracking), which
/// is why `ChallengeCard.showMeta` is opt-in rather than always on.
///
/// ## Days-left is only shown when it is real
///
/// Only a `customRange` challenge has an end date to count down to, and
/// even then only when [Challenge.endDate] is actually set. Every other
/// window is open-ended — a recurring "steps this week" challenge has no
/// deadline, and inventing one ("6 days left" from the week rolling over)
/// would imply the challenge itself expires. So the chip is absent
/// entirely rather than showing a made-up number.
class ChallengeMetaRow extends StatelessWidget {
  const ChallengeMetaRow({super.key, required this.challenge});

  final Challenge challenge;

  /// Whole days from today until [Challenge.endDate], or null when there
  /// is no real deadline. Negative results collapse to 0 ("last day")
  /// rather than a negative countdown — a challenge left active past its
  /// end date is an admin oversight, not something to render as "-3 days".
  static int? daysLeft(Challenge challenge, {DateTime? now}) {
    if (challenge.timeWindow != ChallengeTimeWindow.customRange) return null;
    final end = challenge.endDate;
    if (end == null) return null;

    final today = now ?? DateTime.now();
    final endDay = DateTime(end.year, end.month, end.day);
    final startDay = DateTime(today.year, today.month, today.day);
    final diff = endDay.difference(startDay).inDays;
    return diff < 0 ? 0 : diff;
  }

  @override
  Widget build(BuildContext context) {
    final remaining = daysLeft(challenge);

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _MetaChip(icon: _metricIcon, label: challenge.metric.label),
        _MetaChip(
          icon: AppIcons.calendar,
          label: challenge.timeWindow.label,
        ),
        if (remaining != null)
          _MetaChip(
            icon: AppIcons.duration,
            label: switch (remaining) {
              0 => 'Last day',
              1 => '1 day left',
              _ => '$remaining days left',
            },
            // A closing window is the one piece of metadata here that is
            // time-critical, so it is the only one allowed the accent.
            emphasised: remaining <= 3,
          ),
      ],
    );
  }

  IconData get _metricIcon => switch (challenge.metric) {
    ChallengeMetric.dailySteps ||
    ChallengeMetric.weeklySteps ||
    ChallengeMetric.monthlySteps => AppIcons.steps,
    ChallengeMetric.dailyDistanceKm ||
    ChallengeMetric.totalDistanceKm => AppIcons.distance,
    ChallengeMetric.caloriesBurned => AppIcons.calories,
    ChallengeMetric.activeStreakDays => AppIcons.streak,
    ChallengeMetric.trekCount => AppIcons.hiking,
  };
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.emphasised = false,
  });

  final IconData icon;
  final String label;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final ink = emphasised ? palette.accent : palette.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: emphasised ? palette.accentContainer : palette.cardHigh,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: 13, color: ink),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: ink)),
        ],
      ),
    );
  }
}
