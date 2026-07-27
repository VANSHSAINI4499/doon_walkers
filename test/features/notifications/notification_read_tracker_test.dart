// Device-local notification read state.
//
// This exists because `public.notifications` has no read column — verified
// against the live schema in Phase 13 — so an Unread filter and a bell
// badge both had to be built on local state. That makes these tests the
// only thing standing between the badge and a wrong number.

import 'package:doon_walkers/features/notifications/data/services/notification_read_tracker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<NotificationReadTracker> _tracker([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  return NotificationReadTracker(await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('unreadCount', () {
    test('counts ids not present in the read set', () {
      expect(unreadCount(notificationIds: ['a', 'b', 'c'], readIds: {'a'}), 2);
    });

    test('is 0 when everything is read', () {
      expect(unreadCount(notificationIds: ['a', 'b'], readIds: {'a', 'b'}), 0);
    });

    test('is 0 for an empty list, whatever the read set holds', () {
      expect(unreadCount(notificationIds: const [], readIds: {'a'}), 0);
    });

    test('is the full length when nothing is read', () {
      expect(
        unreadCount(notificationIds: ['a', 'b', 'c'], readIds: const {}),
        3,
      );
    });

    test('a stale read id for a deleted notification does not go negative', () {
      // The read set outlives the rows it refers to, so it can contain ids
      // no longer in the list. That must not make the count wrong.
      expect(
        unreadCount(notificationIds: ['a'], readIds: {'a', 'gone', 'also'}),
        0,
      );
    });
  });

  group('NotificationReadTracker', () {
    test('starts empty for an unknown user', () async {
      final t = await _tracker();
      expect(t.readIds('u1'), isEmpty);
      expect(t.isRead('u1', 'n1'), isFalse);
    });

    test('markRead persists and is readable back', () async {
      final t = await _tracker();
      await t.markRead('u1', ['n1', 'n2']);
      expect(t.readIds('u1'), {'n1', 'n2'});
      expect(t.isRead('u1', 'n1'), isTrue);
      expect(t.isRead('u1', 'n3'), isFalse);
    });

    test('markRead merges rather than replacing', () async {
      final t = await _tracker();
      await t.markRead('u1', ['n1']);
      await t.markRead('u1', ['n2']);
      expect(t.readIds('u1'), {'n1', 'n2'});
    });

    test('markRead reports whether anything actually changed', () async {
      // The caller skips a provider invalidation on false, so a wrong
      // answer here means either a missed refresh or a rebuild loop.
      final t = await _tracker();
      expect(await t.markRead('u1', ['n1']), isTrue);
      expect(await t.markRead('u1', ['n1']), isFalse);
      expect(await t.markRead('u1', ['n1', 'n2']), isTrue);
    });

    test('marking an empty list changes nothing', () async {
      final t = await _tracker();
      expect(await t.markRead('u1', const []), isFalse);
    });

    test('read state is per user — two accounts do not share it', () async {
      // The real scenario this guards: a shared device where signing into a
      // second account would otherwise show every notification pre-read.
      final t = await _tracker();
      await t.markRead('u1', ['n1']);
      expect(t.readIds('u2'), isEmpty);
      expect(t.isRead('u2', 'n1'), isFalse);
    });

    test('clear removes only that user state', () async {
      final t = await _tracker();
      await t.markRead('u1', ['n1']);
      await t.markRead('u2', ['n2']);
      await t.clear('u1');
      expect(t.readIds('u1'), isEmpty);
      expect(t.readIds('u2'), {'n2'});
    });

    test('the stored list is bounded so it cannot grow forever', () async {
      final t = await _tracker();
      await t.markRead('u1', [for (var i = 0; i < 700; i++) 'n$i']);
      expect(t.readIds('u1').length, lessThanOrEqualTo(500));
    });

    test('survives a fresh tracker over the same preferences', () async {
      // Proves it is genuinely persisted, not just held in memory.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await NotificationReadTracker(prefs).markRead('u1', ['n1']);
      expect(NotificationReadTracker(prefs).readIds('u1'), {'n1'});
    });
  });
}
