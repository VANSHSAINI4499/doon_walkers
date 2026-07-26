// Display formatting for the Activity tab. These are all user-visible
// strings, and the fiddly cases (relative period labels, the collapsed
// month in a week range, thousands separators without `intl`) are easy to
// get subtly wrong in ways that only show up on one day of the month.

import 'package:doon_walkers/features/activity/domain/services/activity_period.dart';
import 'package:doon_walkers/features/activity/presentation/widgets/activity_format.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sunday 26 July 2026 — fixed so nothing depends on the wall clock.
final _now = DateTime(2026, 7, 26);

void main() {
  group('steps', () {
    test('inserts thousands separators', () {
      expect(ActivityFormat.steps(8432), '8,432');
      expect(ActivityFormat.steps(1000000), '1,000,000');
    });

    test('leaves short numbers alone', () {
      expect(ActivityFormat.steps(0), '0');
      expect(ActivityFormat.steps(7), '7');
      expect(ActivityFormat.steps(999), '999');
    });

    test('groups correctly at every boundary', () {
      // The off-by-one risk is a leading separator on exact powers.
      expect(ActivityFormat.steps(1000), '1,000');
      expect(ActivityFormat.steps(10000), '10,000');
      expect(ActivityFormat.steps(100000), '100,000');
    });

    test('handles a negative value without a stray separator', () {
      expect(ActivityFormat.steps(-1500), '-1,500');
    });
  });

  group('stepsCompact', () {
    test('passes through under a thousand', () {
      expect(ActivityFormat.stepsCompact(947), '947');
      expect(ActivityFormat.stepsCompact(0), '0');
    });

    test('uses one decimal below ten thousand', () {
      expect(ActivityFormat.stepsCompact(8432), '8.4k');
      expect(ActivityFormat.stepsCompact(1000), '1.0k');
    });

    test('drops the decimal at ten thousand and above', () {
      expect(ActivityFormat.stepsCompact(12300), '12k');
      expect(ActivityFormat.stepsCompact(202000), '202k');
    });
  });

  group('distance and calories', () {
    test('distance is one decimal place', () {
      expect(ActivityFormat.distance(4.234), '4.2 km');
      expect(ActivityFormat.distance(0), '0.0 km');
    });

    test('calories round to whole numbers', () {
      expect(ActivityFormat.calories(311.6), '312 kcal');
      expect(ActivityFormat.calories(0), '0 kcal');
    });
  });

  group('delta', () {
    test('signs a positive value explicitly', () {
      expect(ActivityFormat.delta(12), '+12%');
    });

    test('keeps the native minus sign for a negative', () {
      expect(ActivityFormat.delta(-8), '-8%');
    });

    test('zero is unsigned', () {
      expect(ActivityFormat.delta(0), '0%');
    });
  });

  group('periodLabel — day', () {
    test('today and yesterday read relatively', () {
      expect(
        ActivityFormat.periodLabel(ActivityPeriod.day(_now), now: _now),
        'Today',
      );
      expect(
        ActivityFormat.periodLabel(
          ActivityPeriod.day(DateTime(2026, 7, 25)),
          now: _now,
        ),
        'Yesterday',
      );
    });

    test('an older day in the same year omits the year', () {
      expect(
        ActivityFormat.periodLabel(
          ActivityPeriod.day(DateTime(2026, 3, 12)),
          now: _now,
        ),
        '12 Mar',
      );
    });

    test('a day in a different year includes it', () {
      expect(
        ActivityFormat.periodLabel(
          ActivityPeriod.day(DateTime(2025, 12, 31)),
          now: _now,
        ),
        '31 Dec 2025',
      );
    });
  });

  group('periodLabel — week', () {
    test('the week containing now reads relatively', () {
      expect(
        ActivityFormat.periodLabel(ActivityPeriod.week(_now), now: _now),
        'This week',
      );
    });

    test('a past week within one month collapses the month name', () {
      // Mon 6 – Sun 12 July: "6 – 12 Jul", not "6 Jul – 12 Jul".
      expect(
        ActivityFormat.periodLabel(
          ActivityPeriod.week(DateTime(2026, 7, 8)),
          now: _now,
        ),
        '6 – 12 Jul',
      );
    });

    test('a week spanning two months names both', () {
      // Mon 29 Jun – Sun 5 Jul 2026.
      expect(
        ActivityFormat.periodLabel(
          ActivityPeriod.week(DateTime(2026, 7, 1)),
          now: _now,
        ),
        '29 Jun – 5 Jul',
      );
    });
  });

  group('periodLabel — month', () {
    test('the month containing now reads relatively', () {
      expect(
        ActivityFormat.periodLabel(ActivityPeriod.month(_now), now: _now),
        'This month',
      );
    });

    test('another month this year is just its name', () {
      expect(
        ActivityFormat.periodLabel(
          ActivityPeriod.month(DateTime(2026, 3, 1)),
          now: _now,
        ),
        'March',
      );
    });

    test('a month in another year carries the year', () {
      expect(
        ActivityFormat.periodLabel(
          ActivityPeriod.month(DateTime(2025, 11, 1)),
          now: _now,
        ),
        'November 2025',
      );
    });
  });

  group('weekday helpers', () {
    test('initials follow Monday-first indexing', () {
      // 20 July 2026 is a Monday, 26 July is a Sunday.
      expect(ActivityFormat.weekdayInitial(DateTime(2026, 7, 20)), 'M');
      expect(ActivityFormat.weekdayInitial(DateTime(2026, 7, 26)), 'S');
    });

    test('short names are three letters and correctly offset', () {
      expect(ActivityFormat.weekdayShort(DateTime(2026, 7, 20)), 'Mon');
      expect(ActivityFormat.weekdayShort(DateTime(2026, 7, 22)), 'Wed');
      expect(ActivityFormat.weekdayShort(DateTime(2026, 7, 26)), 'Sun');
    });

    test('month abbreviations are correctly offset', () {
      // The classic bug: a 0-vs-1-indexed month table shifts every label.
      expect(ActivityFormat.monthShort(DateTime(2026, 1, 15)), 'Jan');
      expect(ActivityFormat.monthShort(DateTime(2026, 12, 15)), 'Dec');
    });

    test('dayShort renders the full date', () {
      expect(ActivityFormat.dayShort(DateTime(2026, 7, 26)), '26 Jul 2026');
    });
  });
}
