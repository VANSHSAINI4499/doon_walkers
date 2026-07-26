import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/activity/domain/services/activity_period.dart';
import 'package:doon_walkers/features/activity/domain/services/activity_summary.dart';
import 'package:doon_walkers/features/activity/presentation/providers/activity_dashboard_providers.dart';
import 'package:doon_walkers/features/activity/presentation/widgets/activity_bar_chart.dart';
import 'package:doon_walkers/features/activity/presentation/widgets/activity_format.dart';
import 'package:doon_walkers/features/activity/presentation/widgets/activity_rings.dart';
import 'package:doon_walkers/features/activity/presentation/widgets/cumulative_steps_chart.dart';
import 'package:doon_walkers/features/activity/presentation/widgets/step_goal_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Shared 4 metric tiles: steps, distance, calories, active time.
class _FourMetricTiles extends StatelessWidget {
  const _FourMetricTiles({required this.summary});

  final ActivitySummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                icon: AppIcons.steps,
                value: ActivityFormat.steps(summary.totalSteps),
                label: 'steps',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _MetricTile(
                icon: AppIcons.distance,
                value: ActivityFormat.distance(summary.totalDistanceKm),
                label: 'distance',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                icon: AppIcons.calories,
                value: ActivityFormat.calories(summary.totalCalories),
                label: 'burned',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _MetricTile(
                icon: AppIcons.duration,
                value: '${summary.totalActiveMinutes} mins',
                label: 'active time (est)',
              ),
            ),
          ],
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

/// Insights teaser card shared across views.
class _InsightsTeaserCard extends ConsumerWidget {
  const _InsightsTeaserCard({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final percentileAsync = ref.watch(dailyPercentileProvider(date));

    final title = percentileAsync.when(
      data: (p) => p != null ? 'Top $p% of Doon Walkers today' : 'Community Insights',
      loading: () => 'Loading insights...',
      error: (_, __) => 'Community Insights',
    );

    return AppCard(
      onTap: () => context.push(AppConstants.routeActivityInsights),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: palette.primarySubtle,
              shape: BoxShape.circle,
            ),
            child: AppIcon(AppIcons.insights, size: 20, color: palette.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleSmall),
                const SizedBox(height: 2),
                Text(
                  'Tap to view activity highlights & monthly stats',
                  style: AppTextStyles.secondary(AppTextStyles.bodySmall),
                ),
              ],
            ),
          ),
          AppIcon(AppIcons.chevronRight, color: palette.textSecondary),
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
            // Goal progress ring
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

            // Cumulative progress curve ("Today's progress")
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Today\'s progress', style: AppTextStyles.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    'Cumulative steps curve',
                    style: AppTextStyles.secondary(AppTextStyles.bodySmall),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CumulativeStepsChart(totalSteps: steps, targetSteps: goal),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 4 Metric Tiles
            _FourMetricTiles(summary: summary),
            const SizedBox(height: AppSpacing.md),

            // Insights Teaser
            _InsightsTeaserCard(date: period.to),
            const SizedBox(height: AppSpacing.md),

            // Concentric Activity Rings (3 rings)
            AppCard(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Activity Rings', style: AppTextStyles.titleSmall),
                      TextButton(
                        onPressed: () => context.push(AppConstants.routeActivityInsights),
                        child: Text('View Details', style: AppTextStyles.labelSmall.copyWith(color: palette.primary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ActivityRings(
                    stepsProgress: summary.goalFraction(goal),
                    caloriesProgress: (summary.totalCalories / 400.0).clamp(0.0, 1.0),
                    activeTimeProgress: (summary.totalActiveMinutes / 30.0).clamp(0.0, 1.0),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Last 7 Days Context Chart
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
            const SizedBox(height: AppSpacing.md),

            // Daily Summary Card
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily Summary', style: AppTextStyles.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${ActivityFormat.steps(steps)} total walked on ${period.to.day} ${ActivityFormat.monthShort(period.to)}.',
                    style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
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

        return Column(
          children: [
            _PeriodBody(
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
                    isBestDay: summary.bestDay != null && _sameDay(summary.bestDay!.date, day),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _InsightsTeaserCard(date: period.to),
          ],
        );
      },
    );
  }
}

// ── Month ─────────────────────────────────────────────────────────────

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

        return Column(
          children: [
            _PeriodBody(
              summary: summary,
              goal: goal,
              delta: delta,
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
            ),
            const SizedBox(height: AppSpacing.md),
            _MonthlyGoalModule(summary: summary, dailyGoal: goal),
            const SizedBox(height: AppSpacing.md),
            _InsightsTeaserCard(date: period.to),
          ],
        );
      },
    );
  }
}

/// Monthly goal progress module for Month view.
class _MonthlyGoalModule extends ConsumerWidget {
  const _MonthlyGoalModule({required this.summary, required this.dailyGoal});

  final ActivitySummary summary;
  final int dailyGoal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalAsync = ref.watch(userGoalProvider('monthly_steps'));

    final target = goalAsync.when(
      data: (data) => (data is Map && data['target_value'] != null)
          ? (data['target_value'] as num).toInt()
          : dailyGoal * summary.period.dayCount,
      loading: () => dailyGoal * summary.period.dayCount,
      error: (_, __) => dailyGoal * summary.period.dayCount,
    );

    final fraction = target <= 0 ? 0.0 : (summary.totalSteps / target).clamp(0.0, 1.0);
    final percent = (fraction * 100).round();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Monthly Goal Progress', style: AppTextStyles.titleSmall),
              IconButton(
                icon: const AppIcon(AppIcons.forward, size: 18),
                onPressed: () => context.push(AppConstants.routeMonthlyGoalProgress),
                tooltip: 'Goal Details',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: AppProgressRing(
                  value: fraction,
                  strokeWidth: 6,
                  child: Text('$percent%', style: AppTextStyles.labelSmall),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: AppProgressBar(
                  value: fraction,
                  label: 'Target: ${ActivityFormat.stepsCompact(target)}',
                  trailing: ActivityFormat.steps(summary.totalSteps),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shared Week/Month layout: headline stats, chart, goal bar, 4 metric tiles, breakdown.
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
        _FourMetricTiles(summary: summary),
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
    this.isBestDay = false,
  });

  final String label;
  final String sublabel;
  final int steps;
  final bool hasData;
  final int goal;
  final bool isBestDay;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.titleSmall.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                    if (isBestDay) ...[
                      const SizedBox(width: 4),
                      AppIcon(AppIcons.star, size: 12, color: palette.primary),
                    ],
                  ],
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
                color: palette.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekSpan {
  const _WeekSpan({
    required this.label,
    required this.range,
    required this.start,
    required this.end,
  });

  final String label;
  final String range;
  final DateTime start;
  final DateTime end;

  int get dayCount => end.difference(start).inDays + 1;

  int steps(ActivitySummary summary) {
    var sum = 0;
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      sum += summary.stepsOn(d);
    }
    return sum;
  }

  bool hasData(ActivitySummary summary) {
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      if (summary.byDate.containsKey(DateTime(d.year, d.month, d.day))) {
        return true;
      }
    }
    return false;
  }
}

List<_WeekSpan> _weeksIn(ActivityPeriod period) {
  final out = <_WeekSpan>[];
  var start = period.from;
  var weekIndex = 1;

  while (!start.isAfter(period.to)) {
    final daysLeftInWeek = 7 - (start.weekday - DateTime.monday);
    var end = start.add(Duration(days: daysLeftInWeek - 1));
    if (end.isAfter(period.to)) end = period.to;

    out.add(_WeekSpan(
      label: 'Week $weekIndex',
      range: '${start.day}–${end.day} ${ActivityFormat.monthShort(start)}',
      start: start,
      end: end,
    ));

    weekIndex++;
    start = end.add(const Duration(days: 1));
  }

  return out;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _ViewSkeleton extends StatelessWidget {
  const _ViewSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SkeletonBox(height: 220),
        SizedBox(height: AppSpacing.md),
        SkeletonBox(height: 180),
        SizedBox(height: AppSpacing.md),
        SkeletonBox(height: 120),
      ],
    );
  }
}

class _ViewError extends StatelessWidget {
  const _ViewError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Center(
        child: Column(
          children: [
            AppIcon(AppIcons.error, size: 28, color: palette.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text(
              "Couldn't load activity data",
              style: AppTextStyles.titleSmall.copyWith(
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Retry',
              size: AppButtonSize.small,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
