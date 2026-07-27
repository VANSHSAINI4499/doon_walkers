// Aggregations behind every number on the Activity tab. The cases that
// matter most are the ones that would otherwise produce a plausible-
// looking wrong figure: averaging over the wrong denominator, treating a
// missing day as a zero day, and inventing a percentage against an empty
// baseline.

import 'package:doon_walkers/features/activity/domain/entities/daily_activity.dart';
import 'package:doon_walkers/features/activity/domain/services/activity_period.dart';
import 'package:doon_walkers/features/activity/domain/services/activity_summary.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mon 20 – Sun 26 July 2026.
final _week = ActivityPeriod.week(DateTime(2026, 7, 22));

DailyActivity _row(
  int day, {
  int steps = 5000,
  double km = 3.5,
  double kcal = 200,
}) => DailyActivity(
  date: DateTime(2026, 7, day),
  steps: steps,
  distanceKm: km,
  calories: kcal,
);

void main() {
  group('totals', () {
    test('sums steps, distance and calories across the period', () {
      final s = ActivitySummary.from(_week, [
        _row(20, steps: 1000, km: 1, kcal: 50),
        _row(21, steps: 2000, km: 2, kcal: 100),
      ]);
      expect(s.totalSteps, 3000);
      expect(s.totalDistanceKm, closeTo(3, 0.001));
      expect(s.totalCalories, closeTo(150, 0.001));
    });

    test('ignores rows outside the period', () {
      // Callers may hand over one wide fetch and slice it several ways, so
      // out-of-range rows must not leak into totals.
      final s = ActivitySummary.from(_week, [
        _row(19, steps: 9999), // Sunday before
        _row(20, steps: 1000),
        _row(27, steps: 9999), // Monday after
      ]);
      expect(s.totalSteps, 1000);
      expect(s.daysWithData, 1);
    });

    test('an empty period is all zeroes, not an error', () {
      final s = ActivitySummary.from(_week, const []);
      expect(s.totalSteps, 0);
      expect(s.daysWithData, 0);
      expect(s.activeDays, 0);
      expect(s.averageSteps, 0);
      expect(s.bestDay, isNull);
    });

    test('duplicate rows for one date do not double-count', () {
      final s = ActivitySummary.from(_week, [
        _row(20, steps: 1000, km: 1, kcal: 50),
        _row(20, steps: 4000, km: 4, kcal: 200),
      ]);
      // Last write wins; totals reflect one day, not the sum of both.
      expect(s.totalSteps, 4000);
      expect(s.totalDistanceKm, closeTo(4, 0.001));
      expect(s.daysWithData, 1);
      expect(s.activeDays, 1);
    });
  });

  group('averages', () {
    test('averageSteps divides by days WITH DATA, not days in the period', () {
      // Three synced days in a 7-day week averages over 3. Dividing by 7
      // would punish someone who installed the app on Thursday.
      final s = ActivitySummary.from(_week, [
        _row(20, steps: 3000),
        _row(21, steps: 3000),
        _row(22, steps: 3000),
      ]);
      expect(s.daysWithData, 3);
      expect(s.averageSteps, 3000);
    });

    test('averageStepsOverPeriod divides by every day in the period', () {
      final s = ActivitySummary.from(_week, [_row(20, steps: 7000)]);
      expect(s.averageSteps, 7000);
      expect(s.averageStepsOverPeriod, 1000); // 7000 / 7
    });

    test('averages are 0 rather than NaN when nothing is recorded', () {
      final s = ActivitySummary.from(_week, const []);
      expect(s.averageSteps, 0);
      expect(s.averageStepsOverPeriod, 0);
    });
  });

  group('activeDays vs daysWithData', () {
    test('a synced day with 0 steps counts as data but not as active', () {
      final s = ActivitySummary.from(_week, [
        _row(20, steps: 0),
        _row(21, steps: 5000),
      ]);
      expect(s.daysWithData, 2);
      expect(s.activeDays, 1);
    });

    test('a missing day is neither — absence means unknown, not zero', () {
      final s = ActivitySummary.from(_week, [_row(20, steps: 5000)]);
      expect(s.daysWithData, 1);
      expect(s.activeDays, 1);
      // But for charting purposes it reads as 0 height.
      expect(s.stepsOn(DateTime(2026, 7, 21)), 0);
      expect(s.byDate.containsKey(DateTime(2026, 7, 21)), isFalse);
    });
  });

  group('bestDay', () {
    test('is the highest-step day', () {
      final s = ActivitySummary.from(_week, [
        _row(20, steps: 3000),
        _row(21, steps: 9000),
        _row(22, steps: 5000),
      ]);
      expect(s.bestDay!.date, DateTime(2026, 7, 21));
      expect(s.bestDay!.steps, 9000);
    });

    test('is null when every day is zero — a 0-step "best day" is not one', () {
      final s = ActivitySummary.from(_week, [
        _row(20, steps: 0),
        _row(21, steps: 0),
      ]);
      expect(s.bestDay, isNull);
    });
  });

  group('goal progress', () {
    test('goalFraction is clamped to 1 for drawing bars', () {
      final s = ActivitySummary.from(_week, [_row(20, steps: 100000)]);
      expect(s.goalFraction(6500), 1.0);
    });

    test('goalPercent is NOT clamped — beating a goal should show it', () {
      // Week goal = 6500 * 7 = 45,500. Two days of 30,000 = 60,000 → 132%.
      final s = ActivitySummary.from(_week, [
        _row(20, steps: 30000),
        _row(21, steps: 30000),
      ]);
      expect(s.goalPercent(6500), 132);
      expect(s.goalFraction(6500), 1.0);
    });

    test('a zero or negative goal yields 0, never a divide-by-zero', () {
      final s = ActivitySummary.from(_week, [_row(20, steps: 5000)]);
      expect(s.goalFraction(0), 0);
      expect(s.goalPercent(0), 0);
    });

    test('the day view compares against the daily goal directly', () {
      final day = ActivityPeriod.day(DateTime(2026, 7, 20));
      final s = ActivitySummary.from(day, [_row(20, steps: 3250)]);
      expect(s.goalPercent(6500), 50);
    });
  });

  group('percentChange', () {
    test('computes a normal increase and decrease', () {
      expect(percentChange(current: 110, previous: 100), 10);
      expect(percentChange(current: 90, previous: 100), -10);
    });

    test('is null against a zero baseline, NOT +100%', () {
      // The real case for this app right now: the first synced month has no
      // prior month, and "+100%" would be a fabrication.
      expect(percentChange(current: 5000, previous: 0), isNull);
    });

    test('is null against a negative baseline too', () {
      expect(percentChange(current: 5000, previous: -1), isNull);
    });

    test('is 0 — not null — when both are equal and non-zero', () {
      expect(percentChange(current: 100, previous: 100), 0);
    });

    test('a drop to zero is -100%, which is real', () {
      expect(percentChange(current: 0, previous: 100), -100);
    });

    test('rounds to whole percent', () {
      expect(percentChange(current: 1015, previous: 1000), 2); // 1.5 → 2
    });
  });

  group('stepsOn', () {
    test('returns the day steps and ignores the time component', () {
      final s = ActivitySummary.from(_week, [
        DailyActivity(
          date: DateTime(2026, 7, 21, 14, 30),
          steps: 4321,
          distanceKm: 1,
          calories: 1,
        ),
      ]);
      expect(s.stepsOn(DateTime(2026, 7, 21)), 4321);
      expect(s.stepsOn(DateTime(2026, 7, 21, 23, 59)), 4321);
    });
  });
}
