// Day grouping and the relative timestamp for Points History — mirrors
// notification_grouping_test.dart's coverage exactly (same timezone
// hazards apply: created_at is TIMESTAMPTZ, members are in IST).

import 'package:doon_walkers/features/profile/domain/entities/points_ledger_entry.dart';
import 'package:doon_walkers/features/profile/domain/services/points_history_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixed "now" — 26 July 2026, 14:00 local.
final _now = DateTime(2026, 7, 26, 14);

PointsLedgerEntry _entry(
  String id,
  DateTime createdAt, {
  int points = 10,
  String reason = 'challenge_enrolled',
}) => PointsLedgerEntry(
  id: id,
  points: points,
  reason: reason,
  referenceId: null,
  createdAt: createdAt,
);

List<String> _idsIn(List<PointsHistoryGroup> groups, PointsDayGroup g) =>
    groups
        .where((x) => x.group == g)
        .expand((x) => x.items)
        .map((i) => i.id)
        .toList();

void main() {
  group('groupPointsHistoryByDay', () {
    test('empty input produces no groups, not three empty ones', () {
      expect(groupPointsHistoryByDay(const [], now: _now), isEmpty);
    });

    test('buckets today, yesterday and older correctly', () {
      final groups = groupPointsHistoryByDay([
        _entry('a', DateTime(2026, 7, 26, 9)),
        _entry('b', DateTime(2026, 7, 25, 23)),
        _entry('c', DateTime(2026, 7, 20, 12)),
      ], now: _now);

      expect(groups.length, 3);
      expect(_idsIn(groups, PointsDayGroup.today), ['a']);
      expect(_idsIn(groups, PointsDayGroup.yesterday), ['b']);
      expect(_idsIn(groups, PointsDayGroup.earlier), ['c']);
    });

    test('groups come back in Today, Yesterday, Earlier order', () {
      final groups = groupPointsHistoryByDay([
        _entry('old', DateTime(2026, 7, 1)),
        _entry('today', DateTime(2026, 7, 26, 8)),
      ], now: _now);

      expect(groups.first.group, PointsDayGroup.today);
      expect(groups.last.group, PointsDayGroup.earlier);
    });

    test('omits a group with nothing in it', () {
      final groups = groupPointsHistoryByDay([
        _entry('a', DateTime(2026, 7, 26, 9)),
      ], now: _now);
      expect(groups.length, 1);
      expect(groups.single.group, PointsDayGroup.today);
    });

    test('preserves input order within a group', () {
      final groups = groupPointsHistoryByDay([
        _entry('newest', DateTime(2026, 7, 26, 13)),
        _entry('middle', DateTime(2026, 7, 26, 11)),
        _entry('oldest', DateTime(2026, 7, 26, 8)),
      ], now: _now);
      expect(_idsIn(groups, PointsDayGroup.today), [
        'newest',
        'middle',
        'oldest',
      ]);
    });

    test('a future-dated row files under Today, not Earlier', () {
      final groups = groupPointsHistoryByDay([
        _entry('future', DateTime(2026, 7, 28, 10)),
      ], now: _now);
      expect(groups.single.group, PointsDayGroup.today);
    });

    test('a UTC timestamp is bucketed by its LOCAL date', () {
      final utcLateEvening = DateTime.utc(2026, 7, 25, 20);
      final localDate = utcLateEvening.toLocal();
      final groups = groupPointsHistoryByDay([
        _entry('a', utcLateEvening),
      ], now: DateTime(localDate.year, localDate.month, localDate.day, 14));
      expect(groups.single.group, PointsDayGroup.today);
    });
  });

  group('formatPointsHistoryTime', () {
    test('under a minute reads Just now', () {
      expect(
        formatPointsHistoryTime(
          _now.subtract(const Duration(seconds: 30)),
          now: _now,
        ),
        'Just now',
      );
    });

    test('minutes and hours are terse', () {
      expect(
        formatPointsHistoryTime(
          _now.subtract(const Duration(minutes: 5)),
          now: _now,
        ),
        '5m',
      );
      expect(
        formatPointsHistoryTime(
          _now.subtract(const Duration(hours: 3)),
          now: _now,
        ),
        '3h',
      );
    });

    test('an older date this year omits the year', () {
      expect(
        formatPointsHistoryTime(DateTime(2026, 3, 12, 9), now: _now),
        '12 Mar',
      );
    });

    test('a date in another year includes it', () {
      expect(
        formatPointsHistoryTime(DateTime(2025, 11, 3, 9), now: _now),
        '3 Nov 2025',
      );
    });

    test('a future timestamp reads Just now, never a negative duration', () {
      expect(
        formatPointsHistoryTime(_now.add(const Duration(hours: 2)), now: _now),
        'Just now',
      );
    });
  });
}
