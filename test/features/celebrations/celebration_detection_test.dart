// Pure trigger-detection logic — the exact worked example from the
// brief (goal 6500, before 6420, after 6907) is the primary case; the
// rest cover the edge cases duplicate protection depends on getting
// right (already-reached-before, exactly-at-goal, no movement).

import 'package:doon_walkers/features/celebrations/domain/services/celebration_detection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('didCrossDailyGoal', () {
    test('the brief\'s worked example: 6420 -> 6907 crosses a 6500 goal', () {
      expect(
        didCrossDailyGoal(beforeSteps: 6420, afterSteps: 6907, goal: 6500),
        isTrue,
      );
    });

    test('does not fire again once already reached before this sync', () {
      expect(
        didCrossDailyGoal(beforeSteps: 6500, afterSteps: 6900, goal: 6500),
        isFalse,
      );
      expect(
        didCrossDailyGoal(beforeSteps: 7000, afterSteps: 7100, goal: 6500),
        isFalse,
      );
    });

    test('does not fire when still short of the goal after this sync', () {
      expect(
        didCrossDailyGoal(beforeSteps: 100, afterSteps: 6000, goal: 6500),
        isFalse,
      );
    });

    test('exactly reaching the goal counts as crossing it', () {
      expect(
        didCrossDailyGoal(beforeSteps: 6499, afterSteps: 6500, goal: 6500),
        isTrue,
      );
    });

    test('a non-positive goal never counts as crossed', () {
      expect(
        didCrossDailyGoal(beforeSteps: 0, afterSteps: 100, goal: 0),
        isFalse,
      );
    });

    test('no movement at all never fires', () {
      expect(
        didCrossDailyGoal(beforeSteps: 6907, afterSteps: 6907, goal: 6500),
        isFalse,
      );
    });
  });

  group('didStreakIncrease', () {
    test('the brief\'s worked example: 2-day streak becomes 3', () {
      expect(didStreakIncrease(beforeStreak: 2, afterStreak: 3), isTrue);
    });

    test('an unchanged streak does not count as an increase', () {
      expect(didStreakIncrease(beforeStreak: 3, afterStreak: 3), isFalse);
    });

    test('a broken (decreased) streak does not count as an increase', () {
      expect(didStreakIncrease(beforeStreak: 5, afterStreak: 0), isFalse);
    });

    test('starting a streak from zero counts as an increase', () {
      expect(didStreakIncrease(beforeStreak: 0, afterStreak: 1), isTrue);
    });
  });
}
