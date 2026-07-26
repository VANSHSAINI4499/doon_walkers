import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/activity/domain/services/activity_period.dart';
import 'package:doon_walkers/features/activity/domain/services/activity_summary.dart';
import 'package:doon_walkers/features/activity/presentation/providers/activity_dashboard_providers.dart';
import 'package:doon_walkers/features/activity/presentation/widgets/activity_bar_chart.dart';
import 'package:doon_walkers/features/activity/presentation/widgets/activity_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// **Insights** — a monthly read on the member's own activity, pushed from
/// the Activity tab.
///
/// Everything here is derived from `daily_activity_summary` client-side,
/// except the percentile, which needs the one cross-user aggregate RPC
/// (`get_my_activity_percentile`, 0035).
///
/// ## Deliberately absent
///
///  - **Recent Achievements tiles.** The only tier history that exists is
///    trek-attendance-derived (`get_my_challenge_tier_history`, written
///    before the fitness pivot), so it would put trek medals on a steps
///    screen. Step-tier history would be its own migration.
///  - **Anything social.** No comparisons against named members, no
///    "friends" — the percentile is the only cross-user figure, and it
///    returns a single integer with a k-anonymity floor.
class ActivityInsightsScreen extends ConsumerWidget {
  const ActivityInsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final thisMonth = ActivityPeriod.month(now);
    final lastMonth = thisMonth.previous;

    final currentAsync = ref.watch(activitySummaryProvider(thisMonth));
    final previousAsync = ref.watch(activitySummaryProvider(lastMonth));

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: SafeArea(
        child: currentAsync.when(
          loading: () => const _InsightsSkeleton(),
          error: (error, stack) {
            debugPrint('ActivityInsightsScreen: failed to load: $error');
            return _InsightsError(
              onRetry: () =>
                  ref.invalidate(activitySummaryProvider(thisMonth)),
            );
          },
          data: (current) {
            if (current.daysWithData == 0) {
              return const _InsightsEmpty();
            }
            return _InsightsBody(
              current: current,
              previous: previousAsync.valueOrNull,
              month: thisMonth,
            );
          },
        ),
      ),
    );
  }
}

class _InsightsBody extends ConsumerWidget {
  const _InsightsBody({
    required this.current,
    required this.previous,
    required this.month,
  });

  final ActivitySummary current;
  final ActivitySummary? previous;
  final ActivityPeriod month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final goal = ref.watch(dailyStepGoalProvider);

    final stepsDelta = previous == null
        ? null
        : percentChange(
            current: current.totalSteps,
            previous: previous!.totalSteps,
          );
    final avgDelta = previous == null
        ? null
        : percentChange(
            current: current.averageSteps,
            previous: previous!.averageSteps,
          );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        // ── Monthly overview ──────────────────────────────────────────
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ActivityFormat.periodLabel(month),
                style: AppTextStyles.overline.copyWith(
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              StatDisplay(
                value: ActivityFormat.steps(current.totalSteps),
                label: 'steps this month',
                size: StatSize.hero,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppProgressBar(
                value: current.goalFraction(goal),
                label: 'Monthly goal',
                trailing:
                    '${current.goalPercent(goal)}% of '
                    '${ActivityFormat.stepsCompact(month.stepGoal(goal))}',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Key highlights ────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _HighlightTile(
                icon: AppIcons.steps,
                value: ActivityFormat.stepsCompact(current.totalSteps),
                label: 'total steps',
                delta: stepsDelta,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _HighlightTile(
                icon: AppIcons.trending,
                value: ActivityFormat.stepsCompact(current.averageSteps),
                label: 'avg / day',
                delta: avgDelta,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _HighlightTile(
                icon: AppIcons.distance,
                value: ActivityFormat.distance(current.totalDistanceKm),
                label: 'distance',
                delta: previous == null
                    ? null
                    : percentChange(
                        current: current.totalDistanceKm.round(),
                        previous: previous!.totalDistanceKm.round(),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _HighlightTile(
                icon: AppIcons.calories,
                value: ActivityFormat.calories(current.totalCalories),
                label: 'burned',
                delta: previous == null
                    ? null
                    : percentChange(
                        current: current.totalCalories.round(),
                        previous: previous!.totalCalories.round(),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Week by week ──────────────────────────────────────────────
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Week by week',
                style: AppTextStyles.titleSmall.copyWith(
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ActivityBarChart(
                showValues: true,
                bars: _weekBars(month, current),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Best day ──────────────────────────────────────────────────
        if (current.bestDay != null)
          AppCard(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: palette.primarySubtle,
                    shape: BoxShape.circle,
                  ),
                  child: AppIcon(
                    AppIcons.star,
                    size: 20,
                    color: palette.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Best day',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                      Text(
                        '${ActivityFormat.weekdayShort(current.bestDay!.date)}'
                        ', ${current.bestDay!.date.day} '
                        '${ActivityFormat.monthShort(current.bestDay!.date)}',
                        style: AppTextStyles.titleSmall.copyWith(
                          color: palette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  ActivityFormat.steps(current.bestDay!.steps),
                  style: AppTextStyles.statSmall.copyWith(
                    color: palette.primary,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.md),

        // ── Consistency ───────────────────────────────────────────────
        _ConsistencyCard(summary: current, goal: goal),
        const SizedBox(height: AppSpacing.md),

        // ── Percentile ────────────────────────────────────────────────
        _PercentileCard(month: month.from),
      ],
    );
  }

  /// Bars for each calendar week of the month, clipped to the month.
  static List<ActivityBar> _weekBars(
    ActivityPeriod month,
    ActivitySummary summary,
  ) {
    final bars = <ActivityBar>[];
    var cursor = month.from;
    var index = 1;
    var best = 0;

    final totals = <int>[];
    final labels = <String>[];
    while (!cursor.isAfter(month.to)) {
      final weekEnd = cursor.add(Duration(days: 7 - cursor.weekday));
      final clipped = weekEnd.isAfter(month.to) ? month.to : weekEnd;
      var total = 0;
      for (
        var d = cursor;
        !d.isAfter(clipped);
        d = d.add(const Duration(days: 1))
      ) {
        total += summary.stepsOn(d);
      }
      totals.add(total);
      labels.add('W$index');
      if (total > best) best = total;
      cursor = clipped.add(const Duration(days: 1));
      index++;
    }

    for (var i = 0; i < totals.length; i++) {
      bars.add(
        ActivityBar(
          label: labels[i],
          value: totals[i],
          // Only mark a best week when there is something to be best at.
          highlight: best > 0 && totals[i] == best,
        ),
      );
    }
    return bars;
  }
}

class _HighlightTile extends StatelessWidget {
  const _HighlightTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.delta,
  });

  final IconData icon;
  final String value;
  final String label;
  final int? delta;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final d = delta;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(icon, size: 18, color: palette.textSecondary),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: AppTextStyles.statSmall.copyWith(
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.statLabel.copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (d == null)
            Text(
              'vs last month —',
              style: AppTextStyles.labelSmall.copyWith(
                color: palette.textDisabled,
              ),
            )
          else
            Row(
              children: [
                AppIcon(
                  d >= 0 ? AppIcons.trending : AppIcons.trendingDown,
                  size: 13,
                  color: d >= 0 ? palette.primary : palette.textSecondary,
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    ActivityFormat.delta(d),
                    maxLines: 1,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: d >= 0 ? palette.primary : palette.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Days active this month against a threshold.
///
/// "Active" is days with any steps at all, matching the engine's own
/// definition (`steps > 0`) so this number can't disagree with a streak.
/// The threshold shown alongside is days that *met the goal*, which is a
/// harder and more useful bar than merely moving.
class _ConsistencyCard extends StatelessWidget {
  const _ConsistencyCard({required this.summary, required this.goal});

  final ActivitySummary summary;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final daysMetGoal = summary.byDate.values
        .where((d) => d.steps >= goal)
        .length;
    final dayCount = summary.period.dayCount;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Consistency',
            style: AppTextStyles.titleSmall.copyWith(
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: StatDisplay(
                  value: '${summary.activeDays}',
                  label: 'active days',
                  size: StatSize.medium,
                ),
              ),
              Expanded(
                child: StatDisplay(
                  value: '$daysMetGoal',
                  label: 'days at goal',
                  size: StatSize.medium,
                  color: daysMetGoal > 0 ? palette.primary : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppProgressBar(
            value: dayCount == 0 ? 0 : summary.activeDays / dayCount,
            label: 'Days you moved',
            trailing: '${summary.activeDays} of $dayCount',
          ),
        ],
      ),
    );
  }
}

/// "More active than X% of Doon Walkers", or nothing at all.
///
/// Renders **nothing** when the RPC returns null — which means either
/// fewer than 5 members tracked that month (the k-anonymity floor) or the
/// caller has no data. Showing "0%" there would read as "you are the least
/// active member", which would be both wrong and discouraging.
class _PercentileCard extends ConsumerWidget {
  const _PercentileCard({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final percentile = ref.watch(activityPercentileProvider(month)).valueOrNull;

    if (percentile == null) return const SizedBox.shrink();

    return AppCard(
      child: Row(
        children: [
          AppIcon(AppIcons.group, size: 20, color: palette.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'More active than $percentile% of Doon Walkers tracking this '
              'month.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: palette.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsEmpty extends StatelessWidget {
  const _InsightsEmpty();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Center(
      child: Padding(
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
                AppIcons.insights,
                size: 32,
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Nothing to compare yet',
              style: AppTextStyles.titleMedium.copyWith(
                color: palette.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Once a few days of this month have synced, your monthly '
              'insights will show up here.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: palette.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightsError extends StatelessWidget {
  const _InsightsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(AppIcons.error, size: 40, color: palette.danger),
            const SizedBox(height: AppSpacing.md),
            Text(
              "Couldn't load your insights.",
              style: AppTextStyles.titleMedium.copyWith(
                color: palette.textPrimary,
              ),
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

class _InsightsSkeleton extends StatelessWidget {
  const _InsightsSkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(AppSpacing.lg),
    child: Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkeletonBox(height: 200, borderRadius: AppRadius.card),
          SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: SkeletonBox(height: 120, borderRadius: AppRadius.card),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: SkeletonBox(height: 120, borderRadius: AppRadius.card),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          SkeletonBox(height: 200, borderRadius: AppRadius.card),
        ],
      ),
    ),
  );
}
