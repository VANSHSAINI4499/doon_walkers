// Day grouping and the relative timestamp. Both are timezone-sensitive:
// `created_at` is TIMESTAMPTZ, and this app's members are in IST (UTC+5:30),
// so a notification sent late in the UTC day is already the next day
// locally. Comparing on the UTC date would file it under the wrong heading
// for exactly the users who have it — hence the explicit local-date tests.

import 'package:doon_walkers/features/notifications/domain/entities/notification_item.dart';
import 'package:doon_walkers/features/notifications/domain/services/notification_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixed "now" — 26 July 2026, 14:00 local.
final _now = DateTime(2026, 7, 26, 14);

NotificationItem _item(String id, DateTime createdAt, {String? targetUserId}) =>
    NotificationItem(
      id: id,
      title: 'T$id',
      body: 'B$id',
      createdAt: createdAt,
      targetUserId: targetUserId,
    );

List<String> _idsIn(List<NotificationGroup> groups, NotificationDayGroup g) =>
    groups
        .where((x) => x.group == g)
        .expand((x) => x.items)
        .map((i) => i.id)
        .toList();

void main() {
  group('groupNotificationsByDay', () {
    test('empty input produces no groups, not three empty ones', () {
      expect(groupNotificationsByDay(const [], now: _now), isEmpty);
    });

    test('buckets today, yesterday and older correctly', () {
      final groups = groupNotificationsByDay([
        _item('a', DateTime(2026, 7, 26, 9)),
        _item('b', DateTime(2026, 7, 25, 23)),
        _item('c', DateTime(2026, 7, 20, 12)),
      ], now: _now);

      expect(groups.length, 3);
      expect(_idsIn(groups, NotificationDayGroup.today), ['a']);
      expect(_idsIn(groups, NotificationDayGroup.yesterday), ['b']);
      expect(_idsIn(groups, NotificationDayGroup.earlier), ['c']);
    });

    test('groups come back in Today, Yesterday, Earlier order', () {
      // Input is newest-first from the query; the headings must still read
      // top-down in time order.
      final groups = groupNotificationsByDay([
        _item('old', DateTime(2026, 7, 1)),
        _item('today', DateTime(2026, 7, 26, 8)),
      ], now: _now);

      expect(groups.first.group, NotificationDayGroup.today);
      expect(groups.last.group, NotificationDayGroup.earlier);
    });

    test('omits a group with nothing in it', () {
      final groups = groupNotificationsByDay([
        _item('a', DateTime(2026, 7, 26, 9)),
      ], now: _now);
      expect(groups.length, 1);
      expect(groups.single.group, NotificationDayGroup.today);
    });

    test('preserves input order within a group', () {
      final groups = groupNotificationsByDay([
        _item('newest', DateTime(2026, 7, 26, 13)),
        _item('middle', DateTime(2026, 7, 26, 11)),
        _item('oldest', DateTime(2026, 7, 26, 8)),
      ], now: _now);
      expect(_idsIn(groups, NotificationDayGroup.today), [
        'newest',
        'middle',
        'oldest',
      ]);
    });

    test('midnight boundaries land on the right side', () {
      final groups = groupNotificationsByDay([
        _item('todayStart', DateTime(2026, 7, 26)),
        _item('yesterdayEnd', DateTime(2026, 7, 25, 23, 59, 59)),
      ], now: _now);
      expect(_idsIn(groups, NotificationDayGroup.today), ['todayStart']);
      expect(_idsIn(groups, NotificationDayGroup.yesterday), ['yesterdayEnd']);
    });

    test('two days ago is Earlier, not Yesterday', () {
      final groups = groupNotificationsByDay([
        _item('a', DateTime(2026, 7, 24, 12)),
      ], now: _now);
      expect(groups.single.group, NotificationDayGroup.earlier);
    });

    test('a future-dated row files under Today, not Earlier', () {
      // Clock skew or an admin backdating. Filing it under "Earlier" would
      // bury the newest item at the bottom of the list.
      final groups = groupNotificationsByDay([
        _item('future', DateTime(2026, 7, 28, 10)),
      ], now: _now);
      expect(groups.single.group, NotificationDayGroup.today);
    });

    test('a UTC timestamp is bucketed by its LOCAL date', () {
      // The real hazard: 2026-07-25T20:00Z is 26 July 01:30 IST. On a
      // device in IST that must read as Today.
      final utcLateEvening = DateTime.utc(2026, 7, 25, 20);
      final localDate = utcLateEvening.toLocal();
      final groups = groupNotificationsByDay([
        _item('a', utcLateEvening),
      ], now: DateTime(localDate.year, localDate.month, localDate.day, 14));
      expect(groups.single.group, NotificationDayGroup.today);
    });
  });

  group('formatNotificationTime', () {
    test('under a minute reads Just now', () {
      expect(
        formatNotificationTime(
          _now.subtract(const Duration(seconds: 30)),
          now: _now,
        ),
        'Just now',
      );
    });

    test('minutes and hours are terse', () {
      expect(
        formatNotificationTime(
          _now.subtract(const Duration(minutes: 5)),
          now: _now,
        ),
        '5m',
      );
      expect(
        formatNotificationTime(
          _now.subtract(const Duration(hours: 3)),
          now: _now,
        ),
        '3h',
      );
    });

    test('59 minutes is minutes, 60 is hours', () {
      expect(
        formatNotificationTime(
          _now.subtract(const Duration(minutes: 59)),
          now: _now,
        ),
        '59m',
      );
      expect(
        formatNotificationTime(
          _now.subtract(const Duration(minutes: 60)),
          now: _now,
        ),
        '1h',
      );
    });

    test('23 hours is hours, past that falls to a date or Yesterday', () {
      expect(
        formatNotificationTime(
          _now.subtract(const Duration(hours: 23)),
          now: _now,
        ),
        '23h',
      );
      // 25h before 26 Jul 14:00 is 25 Jul 13:00 — the previous day.
      expect(
        formatNotificationTime(
          _now.subtract(const Duration(hours: 25)),
          now: _now,
        ),
        'Yesterday',
      );
    });

    test('an older date this year omits the year', () {
      expect(
        formatNotificationTime(DateTime(2026, 3, 12, 9), now: _now),
        '12 Mar',
      );
    });

    test('a date in another year includes it', () {
      expect(
        formatNotificationTime(DateTime(2025, 11, 3, 9), now: _now),
        '3 Nov 2025',
      );
    });

    test('a future timestamp reads Just now, never a negative duration', () {
      expect(
        formatNotificationTime(_now.add(const Duration(hours: 2)), now: _now),
        'Just now',
      );
    });
  });

  group('NotificationItem.isTargeted', () {
    test('null target_user_id is a broadcast', () {
      expect(_item('a', _now).isTargeted, isFalse);
    });

    test('a set target_user_id is targeted', () {
      expect(_item('a', _now, targetUserId: 'u1').isTargeted, isTrue);
    });
  });
}
