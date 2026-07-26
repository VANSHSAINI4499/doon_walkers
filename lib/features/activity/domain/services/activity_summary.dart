import 'package:doon_walkers/features/activity/domain/entities/daily_activity.dart';
import 'package:doon_walkers/features/activity/domain/services/activity_period.dart';

/// Aggregations over `daily_activity_summary` rows for one
/// [ActivityPeriod] — totals, averages, best day, consistency, and the
/// change against the previous period.
///
/// Pure, so every rule below is directly testable. The subtle ones, all of
/// which produce plausible-looking wrong numbers if got wrong:
///
///  - **Averages divide by days *with data*, not by days in the period.**
///    A week with three synced days averages over three. Dividing by 7
///    would silently punish someone who installed the app on Thursday, and
///    would make "avg/day" drift downward every time a sync fails.
///    [averageStepsOverPeriod] is available where the other reading is
///    wanted (month goal pacing), and is named to say so.
///  - **A missing day is not a zero day.** Rows only exist for days the
///    provider actually returned (`HealthConnectProvider` skips days with
///    no activity at all), so absence means "unknown", not "walked 0".
///    That is why [daysWithData] and [activeDays] are different numbers.
///  - **Percent change against an empty baseline is null, not ±100%.**
///    With no previous-period data there is nothing to compare to, and
///    "+100%" would be a fabrication. Callers render "no comparison yet".
class ActivitySummary {
  const ActivitySummary({
    required this.period,
    required this.byDate,
    required this.totalSteps,
    required this.totalDistanceKm,
    required this.totalCalories,
    required this.daysWithData,
    required this.activeDays,
    required this.bestDay,
  });

  final ActivityPeriod period;

  /// Steps per day, keyed by date-only. Only days that have a row.
  final Map<DateTime, DailyActivity> byDate;

  final int totalSteps;
  final double totalDistanceKm;
  final double totalCalories;

  /// Days in the period that have a row at all.
  final int daysWithData;

  /// Days in the period with steps > 0. Never greater than [daysWithData].
  final int activeDays;

  /// The day with the most steps, or null when nothing was recorded.
  final DailyActivity? bestDay;

  /// Mean steps across the days that actually have data. 0 when none do.
  ///
  /// This is the "avg/day" the Week and Month views show — see the class
  /// doc for why it is not divided by [ActivityPeriod.dayCount].
  int get averageSteps =>
      daysWithData == 0 ? 0 : (totalSteps / daysWithData).round();

  /// Mean steps spread across *every* day in the period, including days
  /// with no data. Only meaningful for pacing against a period goal
  /// ("are you on track for the month"), never as "your average".
  int get averageStepsOverPeriod =>
      period.dayCount == 0 ? 0 : (totalSteps / period.dayCount).round();

  /// Progress toward the period's derived goal, 0–1 (clamped).
  double goalFraction(int dailyGoal) {
    final goal = period.stepGoal(dailyGoal);
    if (goal <= 0) return 0;
    return (totalSteps / goal).clamp(0.0, 1.0);
  }

  /// Progress toward the period's goal as a whole percentage.
  ///
  /// Deliberately **not** clamped: beating a goal should read "126%", not
  /// a flat 100%. [goalFraction] is the clamped one, for drawing bars.
  int goalPercent(int dailyGoal) {
    final goal = period.stepGoal(dailyGoal);
    if (goal <= 0) return 0;
    return (totalSteps / goal * 100).round();
  }

  /// Builds a summary for [period] from [rows], which may contain days
  /// outside it — anything out of range is ignored, so a caller can hand
  /// over one wide fetch and slice it several ways.
  factory ActivitySummary.from(ActivityPeriod period, List<DailyActivity> rows) {
    final byDate = <DateTime, DailyActivity>{};
    var totalSteps = 0;
    var totalDistance = 0.0;
    var totalCalories = 0.0;
    var activeDays = 0;
    DailyActivity? best;

    for (final row in rows) {
      final date = DateTime(row.date.year, row.date.month, row.date.day);
      if (!period.contains(date)) continue;
      // Last write wins on a duplicate date. The UNIQUE(user_id, date)
      // constraint should prevent it; this just keeps totals from
      // double-counting if a caller merges two fetches.
      if (byDate.containsKey(date)) {
        final existing = byDate[date]!;
        totalSteps -= existing.steps;
        totalDistance -= existing.distanceKm;
        totalCalories -= existing.calories;
        if (existing.steps > 0) activeDays--;
      }
      byDate[date] = row;
      totalSteps += row.steps;
      totalDistance += row.distanceKm;
      totalCalories += row.calories;
      if (row.steps > 0) activeDays++;
      if (best == null || row.steps > best.steps) best = row;
    }

    return ActivitySummary(
      period: period,
      byDate: byDate,
      totalSteps: totalSteps,
      totalDistanceKm: totalDistance,
      totalCalories: totalCalories,
      daysWithData: byDate.length,
      activeDays: activeDays,
      // A "best day" of 0 steps is not a best day — leave it null so the
      // UI shows nothing rather than "Best day: Tuesday, 0 steps".
      bestDay: (best != null && best.steps > 0) ? best : null,
    );
  }

  /// Steps on [date], or 0 when there is no row.
  ///
  /// 0 is the right answer *for charting* (a bar of no height), even
  /// though absence technically means "unknown" — see [byDate] if the
  /// distinction matters.
  int stepsOn(DateTime date) =>
      byDate[DateTime(date.year, date.month, date.day)]?.steps ?? 0;
}

/// Percentage change from [previous] to [current], or null when there is
/// no usable baseline.
///
/// Null — rather than 0 or ±100 — whenever [previous] is 0, because
/// "infinitely more than nothing" is not a percentage. The Activity tab
/// renders that as "no comparison yet", which is the honest reading for a
/// user whose first synced month has no prior month to beat.
int? percentChange({required int current, required int previous}) {
  if (previous <= 0) return null;
  return ((current - previous) / previous * 100).round();
}
