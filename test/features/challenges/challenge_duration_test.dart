// challengeDurationDays — Phase 24's Explore duration filter. The
// important cases are the ones with NO derivable duration (allTime, a
// customRange missing a date): they must return null, never a fabricated
// number, since `filterChallenges` treats null as "always matches".

import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/domain/services/challenge_duration.dart';
import 'package:flutter_test/flutter_test.dart';

Challenge _challenge({
  required ChallengeTimeWindow timeWindow,
  DateTime? startDate,
  DateTime? endDate,
}) => Challenge(
  id: 'c1',
  title: 'T',
  description: '',
  metric: ChallengeMetric.dailySteps,
  timeWindow: timeWindow,
  startDate: startDate,
  endDate: endDate,
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  group('challengeDurationDays', () {
    test('daily is 1 day', () {
      expect(
        challengeDurationDays(_challenge(timeWindow: ChallengeTimeWindow.daily)),
        1,
      );
    });

    test('weekly is 7 days', () {
      expect(
        challengeDurationDays(_challenge(timeWindow: ChallengeTimeWindow.weekly)),
        7,
      );
    });

    test('monthly is approximated as 30 days', () {
      expect(
        challengeDurationDays(_challenge(timeWindow: ChallengeTimeWindow.monthly)),
        30,
      );
    });

    test('allTime has no derivable duration — null, not a fabricated number', () {
      expect(
        challengeDurationDays(_challenge(timeWindow: ChallengeTimeWindow.allTime)),
        isNull,
      );
    });

    test('customRange with both dates set returns the real day span', () {
      expect(
        challengeDurationDays(
          _challenge(
            timeWindow: ChallengeTimeWindow.customRange,
            startDate: DateTime(2026, 3, 1),
            endDate: DateTime(2026, 3, 15),
          ),
        ),
        14,
      );
    });

    test('customRange missing either date is null, not a guess', () {
      expect(
        challengeDurationDays(
          _challenge(timeWindow: ChallengeTimeWindow.customRange, startDate: DateTime(2026, 3, 1)),
        ),
        isNull,
      );
      expect(
        challengeDurationDays(
          _challenge(timeWindow: ChallengeTimeWindow.customRange, endDate: DateTime(2026, 3, 1)),
        ),
        isNull,
      );
      expect(
        challengeDurationDays(_challenge(timeWindow: ChallengeTimeWindow.customRange)),
        isNull,
      );
    });
  });
}
