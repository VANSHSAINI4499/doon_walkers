// Date-range maths for the Activity tab. Every off-by-one in here
// misattributes real steps to the wrong week or drops the last day of a
// month — wrong numbers that look plausible, which is the worst kind.

import 'package:doon_walkers/features/activity/domain/services/activity_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActivityPeriod.day', () {
    test('spans exactly one day and strips the time', () {
      final p = ActivityPeriod.day(DateTime(2026, 7, 26, 18, 42));
      expect(p.from, DateTime(2026, 7, 26));
      expect(p.to, DateTime(2026, 7, 26));
      expect(p.dayCount, 1);
    });
  });

  group('ActivityPeriod.week', () {
    test('starts Monday and ends Sunday for a midweek date', () {
      // 2026-07-26 is a Sunday; its week is Mon 20 – Sun 26.
      final p = ActivityPeriod.week(DateTime(2026, 7, 22)); // Wednesday
      expect(p.from, DateTime(2026, 7, 20));
      expect(p.to, DateTime(2026, 7, 26));
      expect(p.dayCount, 7);
    });

    test('a Monday is the first day of its own week, not the last', () {
      final p = ActivityPeriod.week(DateTime(2026, 7, 20));
      expect(p.from, DateTime(2026, 7, 20));
    });

    test('a Sunday belongs to the week that STARTED six days earlier', () {
      // The classic bug: treating Sunday as day 1 would put it in the next
      // week and disagree with ChallengeTimeWindow.weekly.
      final p = ActivityPeriod.week(DateTime(2026, 7, 26));
      expect(p.from, DateTime(2026, 7, 20));
      expect(p.to, DateTime(2026, 7, 26));
    });

    test('a week spanning a month boundary keeps all 7 days', () {
      final p = ActivityPeriod.week(DateTime(2026, 8, 1)); // Saturday
      expect(p.from, DateTime(2026, 7, 27));
      expect(p.to, DateTime(2026, 8, 2));
      expect(p.dayCount, 7);
    });
  });

  group('ActivityPeriod.month', () {
    test('covers the whole month inclusive of the last day', () {
      final p = ActivityPeriod.month(DateTime(2026, 7, 15));
      expect(p.from, DateTime(2026, 7, 1));
      expect(p.to, DateTime(2026, 7, 31));
      expect(p.dayCount, 31);
    });

    test('handles 30-day months', () {
      expect(ActivityPeriod.month(DateTime(2026, 4, 10)).dayCount, 30);
    });

    test('handles February in a common year', () {
      final p = ActivityPeriod.month(DateTime(2026, 2, 5));
      expect(p.to, DateTime(2026, 2, 28));
      expect(p.dayCount, 28);
    });

    test('handles February in a leap year', () {
      final p = ActivityPeriod.month(DateTime(2028, 2, 5));
      expect(p.to, DateTime(2028, 2, 29));
      expect(p.dayCount, 29);
    });

    test('handles December without spilling into the next year', () {
      final p = ActivityPeriod.month(DateTime(2026, 12, 9));
      expect(p.from, DateTime(2026, 12, 1));
      expect(p.to, DateTime(2026, 12, 31));
    });
  });

  group('previous / next', () {
    test('day steps by one day across a month boundary', () {
      final p = ActivityPeriod.day(DateTime(2026, 8, 1));
      expect(p.previous.from, DateTime(2026, 7, 31));
      expect(p.previous.next.from, DateTime(2026, 8, 1));
    });

    test('week steps by seven days', () {
      final p = ActivityPeriod.week(DateTime(2026, 7, 22));
      expect(p.previous.from, DateTime(2026, 7, 13));
      expect(p.previous.to, DateTime(2026, 7, 19));
    });

    test('month steps by CALENDAR month, not by day count', () {
      // The bug this guards: subtracting dayCount (31) from 1 March lands
      // in late January, skipping February entirely.
      final march = ActivityPeriod.month(DateTime(2026, 3, 10));
      expect(march.previous.from, DateTime(2026, 2, 1));
      expect(march.previous.to, DateTime(2026, 2, 28));
    });

    test('month wraps the year in both directions', () {
      final jan = ActivityPeriod.month(DateTime(2026, 1, 5));
      expect(jan.previous.from, DateTime(2025, 12, 1));

      final dec = ActivityPeriod.month(DateTime(2026, 12, 5));
      expect(dec.next.from, DateTime(2027, 1, 1));
    });

    test('previous then next round-trips for every granularity', () {
      for (final g in ActivityGranularity.values) {
        final p = ActivityPeriod.of(g, DateTime(2026, 7, 22));
        expect(p.previous.next, p, reason: '$g did not round-trip');
      }
    });
  });

  group('contains / isCurrent / isFuture', () {
    final week = ActivityPeriod.week(DateTime(2026, 7, 22));

    test('contains is inclusive at both ends', () {
      expect(week.contains(DateTime(2026, 7, 20)), isTrue);
      expect(week.contains(DateTime(2026, 7, 26)), isTrue);
      expect(week.contains(DateTime(2026, 7, 19)), isFalse);
      expect(week.contains(DateTime(2026, 7, 27)), isFalse);
    });

    test('contains ignores the time of day', () {
      expect(week.contains(DateTime(2026, 7, 26, 23, 59)), isTrue);
    });

    test('isCurrent is true only for the period holding now', () {
      expect(week.isCurrent(DateTime(2026, 7, 24)), isTrue);
      expect(week.isCurrent(DateTime(2026, 7, 27)), isFalse);
    });

    test('isFuture is true only when the whole window is ahead', () {
      final next = week.next;
      expect(next.isFuture(DateTime(2026, 7, 24)), isTrue);
      // Its own first day is not "future".
      expect(next.isFuture(DateTime(2026, 7, 27)), isFalse);
    });
  });

  group('stepGoal derivation', () {
    test('day is the daily goal itself', () {
      expect(ActivityPeriod.day(DateTime(2026, 7, 26)).stepGoal(6500), 6500);
    });

    test('week is seven times the daily goal', () {
      expect(
        ActivityPeriod.week(DateTime(2026, 7, 22)).stepGoal(6500),
        6500 * 7,
      );
    });

    test('month uses that month own length, not a flat 30', () {
      expect(
        ActivityPeriod.month(DateTime(2026, 7, 1)).stepGoal(6500),
        6500 * 31,
      );
      expect(
        ActivityPeriod.month(DateTime(2026, 2, 1)).stepGoal(6500),
        6500 * 28,
      );
    });
  });

  group('value equality', () {
    test('structurally identical periods are equal and hash the same', () {
      // Required for Riverpod family caching — without it the screen
      // re-fetches on every unrelated rebuild.
      final a = ActivityPeriod.week(DateTime(2026, 7, 22));
      final b = ActivityPeriod.week(DateTime(2026, 7, 24));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different granularities over the same day are NOT equal', () {
      final day = ActivityPeriod.day(DateTime(2026, 7, 1));
      final month = ActivityPeriod.month(DateTime(2026, 7, 1));
      expect(day == month, isFalse);
    });
  });

  group('days', () {
    test('lists every day ascending, first to last', () {
      final days = ActivityPeriod.week(DateTime(2026, 7, 22)).days;
      expect(days.length, 7);
      expect(days.first, DateTime(2026, 7, 20));
      expect(days.last, DateTime(2026, 7, 26));
    });

    test('a month lists exactly dayCount days', () {
      final p = ActivityPeriod.month(DateTime(2026, 2, 1));
      expect(p.days.length, p.dayCount);
      expect(p.days.last, DateTime(2026, 2, 28));
    });
  });
}
