/// Pure trigger-detection for the celebration system — deliberately
/// free of Riverpod/SharedPreferences/widget dependencies, same
/// separation [isNewlyAchievedTier] (challenge_celebration_tracker.dart)
/// already establishes: the DECISION ("did something celebration-worthy
/// just happen") is a plain function callers can unit-test directly,
/// while duplicate protection ([CelebrationTracker]) and presentation
/// (the celebration screens) are separate concerns layered on top by
/// [ActivitySyncController].
///
/// Both functions read a snapshot from BEFORE a sync and one from AFTER
/// it — they do not read time-series data or recompute anything
/// [computeActiveStreak]/[ActivitySummary] already own; this is
/// strictly "did the number I was already given move a certain way."
library;

/// True the moment today's step total reaches [goal] for the first
/// time this sync — [afterSteps] has reached it, [beforeSteps] (the
/// same day's total immediately before this sync ran) had not.
///
/// Matches the brief's worked example exactly: goal 6500, beforeSteps
/// 6420 (not yet reached), afterSteps 6907 (reached) -> true. A sync
/// that finds the goal was ALREADY reached before it ran (beforeSteps
/// >= goal) returns false — that's "already celebrated earlier today,"
/// not a fresh crossing.
bool didCrossDailyGoal({
  required int beforeSteps,
  required int afterSteps,
  required int goal,
}) {
  if (goal <= 0) return false;
  return afterSteps >= goal && beforeSteps < goal;
}

/// True when this sync grew the activity streak
/// ([myActivityStreakProvider]) — e.g. 2-day streak before, 3-day
/// streak after. Doesn't care why it grew (that's entirely
/// [computeActiveStreak]'s business, untouched here) — only that the
/// number the app was already computing went up.
bool didStreakIncrease({required int beforeStreak, required int afterStreak}) {
  return afterStreak > beforeStreak;
}
