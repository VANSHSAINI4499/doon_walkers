// The Challenges header's activity streak is computed client-side because
// no RPC returns one (see activity_streak.dart's doc). That means the rule
// lives in Dart and can silently drift from the engine's `daily_streak`
// CTE (0028_fitness_challenge_engine.sql) — these tests pin it to the
// engine's behaviour case by case, including the grace window that is easy
// to get wrong in either direction.

import 'package:doon_walkers/features/challenges/domain/services/activity_streak.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixed "today" so no test depends on the wall clock.
final _today = DateTime(2026, 7, 26);

ActiveDay _day(int daysAgo, {int steps = 5000}) => ActiveDay(
  date: _today.subtract(Duration(days: daysAgo)),
  steps: steps,
);

int _streak(List<ActiveDay> days) =>
    computeActiveStreak(days, today: _today);

void main() {
  group('computeActiveStreak', () {
    test('no data is 0, not an error', () {
      expect(_streak(const []), 0);
    });

    test('a run ending today counts every day in it', () {
      expect(_streak([_day(0), _day(1), _day(2)]), 3);
    });

    test('today alone is a streak of 1', () {
      expect(_streak([_day(0)]), 1);
    });

    group('the grace window', () {
      test('a run ending yesterday still counts — today is not over', () {
        // The engine's own comment: "yesterday still counts, today isn't
        // over yet". Someone who has not walked before opening the app in
        // the morning must not see their streak read 0.
        expect(_streak([_day(1), _day(2), _day(3)]), 3);
      });

      test('a run ending the day before yesterday is broken', () {
        expect(_streak([_day(2), _day(3), _day(4)]), 0);
      });
    });

    test('only the latest run counts, not the longest', () {
      // A 5-day run last month does not resurrect a broken streak, and
      // does not get added to the current one.
      final days = [
        _day(0),
        _day(1),
        for (var i = 20; i < 25; i++) _day(i),
      ];
      expect(_streak(days), 2);
    });

    test('a gap breaks the run at the gap, not before it', () {
      // Active today, yesterday, then a missed day, then three more.
      final days = [_day(0), _day(1), _day(3), _day(4), _day(5)];
      expect(_streak(days), 2);
    });

    test('zero-step days do not count as active and do break a run', () {
      // A synced row exists for the day but with 0 steps — the engine's
      // `WHERE das.steps > 0` excludes it, so it is a gap, not a link.
      final days = [_day(0), _day(1, steps: 0), _day(2)];
      expect(_streak(days), 1);
    });

    test('a user with only zero-step rows has no streak', () {
      expect(_streak([_day(0, steps: 0), _day(1, steps: 0)]), 0);
    });

    test('duplicate rows for one date are not double-counted', () {
      // Mirrors the engine's `SELECT DISTINCT das.date`. The unique
      // constraint should prevent this, but a caller passing pre-merged
      // data must not be able to inflate a streak.
      final days = [_day(0), _day(0), _day(1), _day(1)];
      expect(_streak(days), 2);
    });

    test('input order does not matter', () {
      final ascending = [_day(3), _day(2), _day(1), _day(0)];
      final descending = [_day(0), _day(1), _day(2), _day(3)];
      final shuffled = [_day(2), _day(0), _day(3), _day(1)];
      expect(_streak(ascending), 4);
      expect(_streak(descending), 4);
      expect(_streak(shuffled), 4);
    });

    test('sub-day time components do not split a calendar day', () {
      // Rows come back as DATE, but a caller parsing a timestamp could
      // carry a time — two moments on the same day are one active day.
      final days = [
        ActiveDay(date: DateTime(2026, 7, 26, 8, 30), steps: 1000),
        ActiveDay(date: DateTime(2026, 7, 26, 19, 45), steps: 2000),
        ActiveDay(date: DateTime(2026, 7, 25, 12), steps: 3000),
      ];
      expect(computeActiveStreak(days, today: _today), 2);
    });

    test('a future-dated row does not break the current run', () {
      // Defensive: a device with a skewed clock could sync tomorrow. The
      // latest run then ends in the future, which is still >= yesterday,
      // so the streak stays alive rather than resetting to 0.
      final days = [_day(-1), _day(0), _day(1)];
      expect(_streak(days), 3);
    });
  });
}
