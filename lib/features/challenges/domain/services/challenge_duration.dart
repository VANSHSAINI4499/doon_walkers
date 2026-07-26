import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';

/// A challenge's length in days, derived from its REAL
/// [Challenge.timeWindow]/dates — never a fabricated number.
///
/// There is no `duration_days` column; `time_window` is a fixed enum
/// (see its own doc), so this maps each recurring window to the actual
/// calendar period it measures:
///  - [ChallengeTimeWindow.daily] → 1 (today)
///  - [ChallengeTimeWindow.weekly] → 7 (Monday–Sunday)
///  - [ChallengeTimeWindow.monthly] → 30 (a calendar month, approximated —
///    the real span is 28–31 depending on the month, and a filter slider
///    needs one stable number, not a monthly-varying one)
///  - [ChallengeTimeWindow.customRange] → the real `endDate - startDate`,
///    when both are set
///  - [ChallengeTimeWindow.allTime] → null — it has no length to measure
///    against, the same way [ChallengeMetaRow.daysLeft] returns null
///    rather than inventing a countdown for a window with no deadline.
///
/// A null result means "exclude this challenge from duration filtering
/// entirely" (it always matches, regardless of the selected range) —
/// see `filterChallenges`'s `durationRange` param.
int? challengeDurationDays(Challenge challenge) {
  switch (challenge.timeWindow) {
    case ChallengeTimeWindow.daily:
      return 1;
    case ChallengeTimeWindow.weekly:
      return 7;
    case ChallengeTimeWindow.monthly:
      return 30;
    case ChallengeTimeWindow.customRange:
      final start = challenge.startDate;
      final end = challenge.endDate;
      if (start == null || end == null) return null;
      final days = end.difference(start).inDays;
      return days < 0 ? null : days;
    case ChallengeTimeWindow.allTime:
      return null;
  }
}
