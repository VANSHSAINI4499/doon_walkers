/// Maps `points_ledger.reason` machine strings to human copy for Points
/// History — the ONE place this mapping lives, per the Phase 22 brief.
///
/// The known reasons, each written by the RPC named in the comment:
///  - `challenge_enrolled` — `enroll_in_challenge()`, +10, one-time per
///    (user, challenge) as of 0039_points_history_and_enrollment_fix.sql.
///  - `daily_step_goal` — awarded client-side via `award_points()` from
///    `ActivityRepositoryImpl._maybeAwardDailyStepGoalPoints`, +25/day.
///  - `trek_checkin` / `challenge_completed` — reserved reason strings the
///    brief names; nothing in this codebase writes them yet, but a row
///    with either still gets its intended label rather than falling
///    through to the generic one.
///
/// Any OTHER reason — one added later without updating this map — falls
/// back to [_genericLabel], never the raw enum string.
class PointsReasonLabels {
  const PointsReasonLabels._();

  static const _labels = <String, String>{
    'challenge_enrolled': 'Joined a challenge',
    'daily_step_goal': 'Hit your daily step goal',
    'trek_checkin': 'Checked in to a trek',
    'challenge_completed': 'Completed a challenge',
  };

  static const _genericLabel = 'Points update';

  static String labelFor(String reason) => _labels[reason] ?? _genericLabel;
}
