// The days-left countdown. The important cases are the ones where there is
// NO real deadline: only a custom_range challenge has an end date, and
// showing a countdown for a recurring weekly/monthly challenge would imply
// the challenge itself expires.

import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/challenge_meta_row.dart';
import 'package:flutter_test/flutter_test.dart';

final _today = DateTime(2026, 7, 26);

Challenge _challenge({
  required ChallengeTimeWindow timeWindow,
  DateTime? endDate,
}) => Challenge(
  id: 'c1',
  title: 'T',
  description: '',
  metric: ChallengeMetric.dailySteps,
  timeWindow: timeWindow,
  endDate: endDate,
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  group('ChallengeMetaRow.daysLeft', () {
    test('null for every window except customRange', () {
      for (final window in ChallengeTimeWindow.values) {
        if (window == ChallengeTimeWindow.customRange) continue;
        expect(
          ChallengeMetaRow.daysLeft(
            // Deliberately WITH an end date: the column is nullable and
            // populated on non-custom windows too (it doubles as a general
            // "earliest/latest that counts" filter), so the window is what
            // must gate the countdown, not merely the date's presence.
            _challenge(timeWindow: window, endDate: DateTime(2026, 8, 30)),
            now: _today,
          ),
          isNull,
          reason: '$window has no deadline to count down to',
        );
      }
    });

    test('null for customRange with no end date set', () {
      expect(
        ChallengeMetaRow.daysLeft(
          _challenge(timeWindow: ChallengeTimeWindow.customRange),
          now: _today,
        ),
        isNull,
      );
    });

    test('counts whole days to the end date', () {
      expect(
        ChallengeMetaRow.daysLeft(
          _challenge(
            timeWindow: ChallengeTimeWindow.customRange,
            endDate: DateTime(2026, 8, 5),
          ),
          now: _today,
        ),
        10,
      );
    });

    test('0 on the final day', () {
      expect(
        ChallengeMetaRow.daysLeft(
          _challenge(
            timeWindow: ChallengeTimeWindow.customRange,
            endDate: _today,
          ),
          now: _today,
        ),
        0,
      );
    });

    test('a past end date clamps to 0, never a negative countdown', () {
      // A challenge left active past its end date is an admin oversight;
      // rendering "-3 days left" would make it look like a bug in the app.
      expect(
        ChallengeMetaRow.daysLeft(
          _challenge(
            timeWindow: ChallengeTimeWindow.customRange,
            endDate: DateTime(2026, 7, 20),
          ),
          now: _today,
        ),
        0,
      );
    });

    test('the time of day does not shift the count', () {
      // Both sides are floored to a date, so an end date carrying a
      // timestamp and a "now" late in the evening still read the same.
      expect(
        ChallengeMetaRow.daysLeft(
          _challenge(
            timeWindow: ChallengeTimeWindow.customRange,
            endDate: DateTime(2026, 7, 28, 23, 59),
          ),
          now: DateTime(2026, 7, 26, 22, 10),
        ),
        2,
      );
    });
  });
}
