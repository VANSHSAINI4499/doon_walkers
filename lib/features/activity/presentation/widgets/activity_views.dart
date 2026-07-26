import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/activity/domain/services/activity_period.dart';
import 'package:doon_walkers/features/activity/domain/services/activity_summary.dart';
import 'package:doon_walkers/features/activity/presentation/providers/activity_dashboard_providers.dart';
import 'package:doon_walkers/features/activity/presentation/widgets/activity_bar_chart.dart';
import 'package:doon_walkers/features/activity/presentation/widgets/activity_format.dart';
import 'package:doon_walkers/features/activity/presentation/widgets/step_goal_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Day / Week / Month bodies of the Activity dashboard.
///
/// All three read the same [activitySummaryProvider] family — the shape of
/// the answer differs, the data path does not.
///
/// ## No "active time" tile anywhere
///
/// The reference shows one. `HealthDataType.EXERCISE_TIME` is **not** in
/// the `health` package's Android list (13.1.3, `heath_data_types.dart`) —
/// it is iOS-only — and there is no `active_minutes` column. `WORKOUT` is
/// available but would read 0 for anyone who walks without logging an
/// exercise session, which is most people. So the tile is omitted rather
/// than filled with a number that means nothing.

/// Shared metric tiles: distance and calories, both real columns.
class _MetricTiles extends StatelessWidget {
  const _MetricTiles({required this.summary});

  final ActivitySummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            icon: AppIcons.distance,
            value: ActivityFormat.distance(summary.totalDistanceKm),
            label: 'distance',
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _MetricTile(
            icon: AppIcons.calories,
            value: ActivityFormat.calories(summary.totalCalories),
            label: 'burned',
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
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
        ],
      ),
    );
  }
}

/// A labelled figure with an optional vs-previous delta.
class PeriodStat extends StatelessWidget {
  const PeriodStat({
    super.key,
    required this.value,
    required this.label,
    this.delta,
    this.size = StatSize.large,
  });

  final String value;
  final String label;

  /// Null renders "no comparison yet" rather than a fabricated 0% — see
  /// [percentChange].
  final int? delta;

  final StatSize size;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final d = delta;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatDisplay(value: value, label: label, size: size),
        const SizedBox(height: AppSpacing.sm),
        if (d == null)
          Text(
            'No comparison yet',
            style: AppTextStyles.labelSmall.copyWith(
              color: palette.textDisabled,
            ),
          )
        else
          Row(
            children: [
              AppIcon(
                d >= 0 ? AppIcons.trending : AppIcons.trendingDown,
                size: 14,
                color: d >= 0 ? palette.primary : palette.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${ActivityFormat.delta(d)} vs previous',
                style: AppTextStyles.labelSmall.copyWith(
                  color: d >= 0 ? palette.primary : palette.textSecondary,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// ── Day ───────────────────────────────────────────────────────────────

/// Steps vs goal as a ring, the two real metric tiles, and a rolling
/// seven-day context chart.
///
/// ## Why there is no hour-by-hour curve
///
/// The reference's Day view charts a cumulative 12AM→12AM line.
/// `daily_activity_summary` holds **one row per day** — there is no
/// intraday data to draw it from, and synthesising a curve would be
/// inventing data.
///
/// Per-hour reads *are* technically possible (`getTotalStepsInInterval`
/// over 24 hourly windows returns real on-device buckets), but only on
/// Android, only while permission is live, and only inside Health
/// Connect's ~30-day retention — so the chart would vanish when paging
/// back past a month, at a cost of 24 queries per date change. A trailing
/// seven-day comparison works for every day, on every platform, from data
/// already synced. That trade is the deliberate choice here.
class ActivityDayView extends ConsumerWidget {
  const ActivityDayView({super.key, required this.period});

  final ActivityPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final goal = ref.watch(dailyStepGoalProvider);
    final summaryAsync = ref.watch(activitySummaryProvider(period));
    final trailingAsync = ref.watch(trailingWeekProvider(period.to));

    return summaryAsync.when(
      loading: () => const _ViewSkeleton(),
      error: (e, _) => _ViewError(
        onRetry: () => ref.invalidate(activitySummaryProvider(period)),
      ),
      data: (summary) {
        final steps = summary.totalSteps;
        final percent = summary.goalPercent(goal);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Column(
                children: [
                  Center(
                    child: AppProgressRing(
                      value: summary.goalFraction(goal),
                      size: 184,
                      strokeWidth: 12,
                      child: StatDisplay(
                        value: ActivityFormat.steps(steps),
                        label: 'steps',
                        size: StatSize.large,
                        alignment: CrossAxisAlignment.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Pressable(
                    onTap: () => showStepGoalSheet(context),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: palette.cardHigh,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$percent% of ${ActivityFormat.steps(goal)}',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: palette.textPrimary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          AppIcon(
                            AppIcons.edit,
                            size: 14,
                            color: palette.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _MetricTiles(summary: summary),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Last 7 days',
                    style: AppTextStyles.titleSmall.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  trailingAsync.when(
                    loading: () => const SizedBox(
                      height: 140,
                      child: Center(child: SkeletonBox(height: 120)),
                    ),
                    error: (e, _) => SizedBox(
                      height: 60,
                      child: Center(
                        child: Text(
                          "Couldn't load recent days.",
                          style: AppTextStyles.bodySmall.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    data: (rows) {
                      final byDate = {
                        for (final r in rows)
                          DateTime(r.date.year, r.date.month, r.date.day):
                              r.steps,
                      };
                      final start = period.to.subtract(
                        const Duration(days: 6),
                      );
                      return ActivityBarChart(
                        goal: goal,
                        bars: [
                          for (var i = 0; i < 7; i++)
                            () {
                              final d = start.add(Duration(days: i));
                              return ActivityBar(
                                label: ActivityFormat.weekdayInitial(d),
                                value: byDate[d] ?? 0,
                                emphasise: d == period.to,
                              );
                            }(),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Week ──────────────────────────────────────────────────────────────

/// Week total, average per day with data, per-day bars with the best day
/// highlighted, and a per-day breakdown list.
class ActivityWeekView extends ConsumerWidget {
  const ActivityWeekView({super.key, required this.period});

  final ActivityPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(dailyStepGoalProvider);
    final summaryAsync = ref.watch(activitySummaryProvider(period));
    final previousAsync = ref.watch(activitySummaryProvider(period.previous));

    return summaryAsync.when(
      loading: () => const _ViewSkeleton(),
      error: (e, _) => _ViewError(
        onRetry: () => ref.invalidate(activitySummaryProvider(period)),
      ),
      data: (summary) {
        final previous = previousAsync.valueOrNull;
        final delta = previous == null
            ? null
            : percentChange(
                current: summary.totalSteps,
                previous: previous.totalSteps,
              );

        return _PeriodBody(
          summary: summary,
          goal: goal,
          delta: delta,
          bars: [
            for (final day in period.days)
              ActivityBar(
                label: ActivityFormat.weekdayInitial(day),
                value: summary.stepsOn(day),
                highlight:
                    summary.bestDay != null &&
                    _sameDay(summary.bestDay!.date, day),
              ),
          ],
          showBarValues: true,
          breakdown: [
            for (final day in period.days.reversed)
              _BreakdownRow(
                label: ActivityFormat.weekdayShort(day),
                sublabel: '${day.day} ${ActivityFormat.monthShort(day)}',
                steps: summary.stepsOn(day),
                hasData: summary.byDate.containsKey(day),
                goal: goal,
              ),
          ],
        );
      },
    );
  }
}

// ── Month ─────────────────────────────────────────────────────────────

/// Month total, average, per-day bars, goal progress against the derived
/// monthly target, and a per-week breakdown.
class ActivityMonthView extends ConsumerWidget {
  const ActivityMonthView({super.key, required this.period});

  final ActivityPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(dailyStepGoalProvider);
    final summaryAsync = ref.watch(activitySummaryProvider(period));
    final previousAsync = ref.watch(activitySummaryProvider(period.previous));

    return summaryAsync.when(
      loading: () => const _ViewSkeleton(),
      error: (e, _) => _ViewError(
        onRetry: () => ref.invalidate(activitySummaryProvider(period)),
      ),
      data: (summary) {
        final previous = previousAsync.valueOrNull;
        final delta = previous == null
            ? null
            : percentChange(
                current: summary.totalSteps,
                previous: previous.totalSteps,
              );

        return _PeriodBody(
          summary: summary,
          goal: goal,
          delta: delta,
          // Labelled every 5th day: 31 numbers would overlap into mush.
          bars: [
            for (final day in period.days)
              ActivityBar(
                label: day.day == 1 || day.day % 5 == 0 ? '${day.day}' : '',
                value: summary.stepsOn(day),
                highlight:
                    summary.bestDay != null &&
                    _sameDay(summary.bestDay!.date, day),
              ),
          ],
          breakdown: [
            for (final week in _weeksIn(period))
              _BreakdownRow(
                label: week.label,
                sublabel: week.range,
                steps: week.steps(summary),
                hasData: week.hasData(summary),
                goal: goal * week.dayCount,
              ),
          ],
        );
      },
    );
  }
}

/// Shared Week/Month layout: headline stats, chart, goal bar, breakdown.
class _PeriodBody extends StatelessWidget {
  const _PeriodBody({
    required this.summary,
    required this.goal,
    required this.delta,
    required this.bars,
    required this.breakdown,
    this.showBarValues = false,
  });

  final ActivitySummary summary;
  final int goal;
  final int? delta;
  final List<ActivityBar> bars;
  final List<Widget> breakdown;
  final bool showBarValues;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final periodGoal = summary.period.stepGoal(goal);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PeriodStat(
                value: ActivityFormat.steps(summary.totalSteps),
                label: 'total steps',
                delta: delta,
              ),
              const SizedBox(height: AppSpacing.xl),
              Divider(color: palette.border, height: 1),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: StatDisplay(
                      value: ActivityFormat.steps(summary.averageSteps),
                      label: 'avg / active day',
                      size: StatSize.medium,
                    ),
                  ),
                  Expanded(
                    child: StatDisplay(
                      value:
                          '${summary.daysWithData}/${summary.period.dayCount}',
                      label: 'days synced',
                      size: StatSize.medium,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Steps per day',
                style: AppTextStyles.titleSmall.copyWith(
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ActivityBarChart(
                bars: bars,
                goal: goal,
                showValues: showBarValues,
                height: 150,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: AppProgressBar(
            value: summary.goalFraction(goal),
            label: 'Goal progress',
            trailing:
                '${ActivityFormat.stepsCompact(summary.totalSteps)} / '
                '${ActivityFormat.stepsCompact(periodGoal)}',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _MetricTiles(summary: summary),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(children: breakdown),
        ),
      ],
    );
  }
}

/// One row in a Week/Month breakdown list.
class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.sublabel,
    required this.steps,
    required this.hasData,
    required this.goal,
  });

  final String label;
  final String sublabel;
  final int steps;

  /// False when no row exists for this span at all — rendered as "—",
  /// distinct from a real zero-step day.
  final bool hasData;

  final int goal;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final met = hasData && goal > 0 && steps >= goal;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: palette.textPrimary,
                  ),
                ),
                Text(
                  sublabel,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: AppProgressBar(
              value: goal <= 0 ? 0 : steps / goal,
              height: 5,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: 62,
            child: Text(
              hasData ? ActivityFormat.stepsCompact(steps) : '—',
              textAlign: TextAlign.right,
              style: AppTextStyles.labelMedium.copyWith(
                color: hasData ? palette.textPrimary : palette.textDisabled,
              ),
            ),
          ),
          if (met)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xs),
              child: AppIcon(
                AppIcons.checkCircle,
                size: 15,
                color: palette.primary,
              ),
            )
          else
            const SizedBox(width: 19),
        ],
      ),
    );
  }
}

/// A calendar week clipped to a month, for the Month view's breakdown.
class _MonthWeek {
  const _MonthWeek({
    required this.label,
    required this.range,
    required this.days,
  });

  final String label;
  final String range;
  final List<DateTime> days;

  int get dayCount => days.length;

  int steps(ActivitySummary s) =>
      days.fold(0, (sum, d) => sum + s.stepsOn(d));

  bool hasData(ActivitySummary s) =>
      days.any((d) => s.byDate.containsKey(d));
}

/// Splits [period] into its calendar weeks, each **clipped to the month**
/// so the first and last are partial rather than spilling into the
/// neighbouring month (whose steps belong to that month's totals).
List<_MonthWeek> _weeksIn(ActivityPeriod period) {
  final weeks = <_MonthWeek>[];
  var cursor = period.from;
  var index = 1;

  while (!cursor.isAfter(period.to)) {
    final weekEnd = cursor.add(Duration(days: 7 - cursor.weekday));
    final clippedEnd = weekEnd.isAfter(period.to) ? period.to : weekEnd;
    final days = <DateTime>[
      for (
        var d = cursor;
        !d.isAfter(clippedEnd);
        d = d.add(const Duration(days: 1))
      )
        d,
    ];
    weeks.add(
      _MonthWeek(
        label: 'Week $index',
        range: '${cursor.day}–${clippedEnd.day}',
        days: days,
      ),
    );
    cursor = clippedEnd.add(const Duration(days: 1));
    index++;
  }

  return weeks.reversed.toList();
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _ViewSkeleton extends StatelessWidget {
  const _ViewSkeleton();

  @override
  Widget build(BuildContext context) => const Shimmer(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SkeletonBox(height: 260, borderRadius: AppRadius.card),
        SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: SkeletonBox(height: 96, borderRadius: AppRadius.card),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: SkeletonBox(height: 96, borderRadius: AppRadius.card),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.md),
        SkeletonBox(height: 200, borderRadius: AppRadius.card),
      ],
    ),
  );
}

class _ViewError extends StatelessWidget {
  const _ViewError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(AppIcons.error, size: 40, color: palette.danger),
          const SizedBox(height: AppSpacing.md),
          Text(
            "Couldn't load your activity.",
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
    );
  }
}
