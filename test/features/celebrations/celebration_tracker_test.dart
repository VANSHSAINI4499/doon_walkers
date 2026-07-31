// CelebrationTracker's date-comparison reset — the specific behaviour
// Part 6 asks for ("reset automatically when the calendar day
// changes") is what these tests pin, not just "a flag can be set."

import 'package:doon_walkers/features/celebrations/data/services/celebration_tracker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('CelebrationTracker', () {
    test('has not happened today when nothing was ever marked', () async {
      SharedPreferences.setMockInitialValues({});
      final tracker = CelebrationTracker(await SharedPreferences.getInstance());

      expect(
        tracker.hasHappenedToday(CelebrationFlag.goalCelebrationShown, 'u1'),
        isFalse,
      );
    });

    test('reads back true immediately after being marked', () async {
      SharedPreferences.setMockInitialValues({});
      final tracker = CelebrationTracker(await SharedPreferences.getInstance());
      final now = DateTime(2026, 7, 30);

      await tracker.markHappenedToday(
        CelebrationFlag.goalCelebrationShown,
        'u1',
        now: now,
      );

      expect(
        tracker.hasHappenedToday(
          CelebrationFlag.goalCelebrationShown,
          'u1',
          now: now,
        ),
        isTrue,
      );
    });

    test('resets automatically once the calendar day changes', () async {
      SharedPreferences.setMockInitialValues({});
      final tracker = CelebrationTracker(await SharedPreferences.getInstance());
      final today = DateTime(2026, 7, 30);
      final tomorrow = DateTime(2026, 7, 31);

      await tracker.markHappenedToday(
        CelebrationFlag.streakCelebrationShown,
        'u1',
        now: today,
      );

      expect(
        tracker.hasHappenedToday(
          CelebrationFlag.streakCelebrationShown,
          'u1',
          now: today,
        ),
        isTrue,
        reason: 'still the same day it was marked',
      );
      expect(
        tracker.hasHappenedToday(
          CelebrationFlag.streakCelebrationShown,
          'u1',
          now: tomorrow,
        ),
        isFalse,
        reason: 'a new calendar day resets the flag with nothing cleared',
      );
    });

    test('flags are independent of each other', () async {
      SharedPreferences.setMockInitialValues({});
      final tracker = CelebrationTracker(await SharedPreferences.getInstance());
      final now = DateTime(2026, 7, 30);

      await tracker.markHappenedToday(
        CelebrationFlag.goalNotificationSent,
        'u1',
        now: now,
      );

      expect(
        tracker.hasHappenedToday(
          CelebrationFlag.goalNotificationSent,
          'u1',
          now: now,
        ),
        isTrue,
      );
      expect(
        tracker.hasHappenedToday(
          CelebrationFlag.goalCelebrationShown,
          'u1',
          now: now,
        ),
        isFalse,
        reason: 'marking one flag must not mark the others',
      );
      expect(
        tracker.hasHappenedToday(
          CelebrationFlag.streakCelebrationShown,
          'u1',
          now: now,
        ),
        isFalse,
      );
      expect(
        tracker.hasHappenedToday(
          CelebrationFlag.streakNotificationSent,
          'u1',
          now: now,
        ),
        isFalse,
      );
    });

    test('flags are scoped per user', () async {
      SharedPreferences.setMockInitialValues({});
      final tracker = CelebrationTracker(await SharedPreferences.getInstance());
      final now = DateTime(2026, 7, 30);

      await tracker.markHappenedToday(
        CelebrationFlag.goalCelebrationShown,
        'user-a',
        now: now,
      );

      expect(
        tracker.hasHappenedToday(
          CelebrationFlag.goalCelebrationShown,
          'user-a',
          now: now,
        ),
        isTrue,
      );
      expect(
        tracker.hasHappenedToday(
          CelebrationFlag.goalCelebrationShown,
          'user-b',
          now: now,
        ),
        isFalse,
      );
    });
  });
}
