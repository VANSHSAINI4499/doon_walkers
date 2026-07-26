import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_progress.dart';

/// The two DB actions the completion-award trigger needs, abstracted so
/// [triggerChallengeCompletedPointsAward] is testable without a real
/// Supabase client — Phase 24. [ChallengeRepositoryImpl] is the real
/// implementation (points_ledger check + award_points RPC); tests supply
/// an in-memory fake instead.
abstract class ChallengeCompletionAwardGateway {
  /// Whether a `challenge_completed` ledger entry already exists for
  /// this (user, challenge) pair.
  Future<bool> hasAwardedChallengeCompleted(String userId, String challengeId);

  /// Records the award — a `points_ledger` insert plus the
  /// `user_points` update, via `award_points()`.
  Future<void> awardChallengeCompleted(
    String userId,
    String challengeId,
    int points,
  );
}

/// For every challenge the user is enrolled in where they've reached
/// the top (platinum) tier, awards `challenge_completed` points once —
/// gated on [ChallengeCompletionAwardGateway.hasAwardedChallengeCompleted]
/// so re-checking progress on every screen visit doesn't re-award.
///
/// "Completed" is `currentTier == platinum` — the only 0–100%-equivalent
/// signal the real tier engine exposes (see [ChallengeProgress]'s doc).
/// This function does not compute progress or tiers; it only reads the
/// tier a caller already computed elsewhere.
///
/// One challenge's gateway failure doesn't stop the others from being
/// checked — mirrors the fire-and-forget, non-fatal error handling
/// `ActivityRepositoryImpl._maybeAwardDailyStepGoalPoints` already
/// established for `daily_step_goal`.
Future<void> triggerChallengeCompletedPointsAward({
  required String userId,
  required List<Challenge> challenges,
  required List<ChallengeProgress> progressList,
  required Set<String> enrolledChallengeIds,
  required ChallengeCompletionAwardGateway gateway,
}) async {
  for (final progress in progressList) {
    if (!enrolledChallengeIds.contains(progress.challengeId)) continue;
    if (progress.currentTier != ChallengeTier.platinum) continue;

    Challenge? challenge;
    for (final c in challenges) {
      if (c.id == progress.challengeId) {
        challenge = c;
        break;
      }
    }
    if (challenge == null) continue;

    try {
      final alreadyAwarded = await gateway.hasAwardedChallengeCompleted(
        userId,
        challenge.id,
      );
      if (alreadyAwarded) continue;

      await gateway.awardChallengeCompleted(
        userId,
        challenge.id,
        challenge.pointValue,
      );
    } catch (_) {
      // Non-fatal — the caller's progress data is unaffected either way.
    }
  }
}
