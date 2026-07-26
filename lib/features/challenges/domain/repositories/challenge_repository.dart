import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_enrollment.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_progress.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_tier_achievement.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_top_participant.dart';
import 'package:doon_walkers/features/challenges/domain/entities/leaderboard_entry.dart';

/// Abstract interface for reading and managing challenges.
///
/// The read methods are safe to call regardless of caller role — RLS
/// (0022_challenges.sql) already restricts what rows come back
/// (`challenges_select`/`challenge_tiers_select`: active-or-admin,
/// same shape as treks/products). The write methods are only ever
/// exposed through admin-gated UI, but RLS enforces the same
/// admin-only rule server-side either way.
abstract class ChallengeRepository {
  /// All challenges, active and draft — admin management list. RLS
  /// only actually returns draft rows to an admin caller; for anyone
  /// else this would behave like an active-only fetch (not currently
  /// exposed to non-admins in this phase — there is no public
  /// Challenges tab yet, that's C2).
  Future<List<Challenge>> fetchAllChallenges();

  /// Active challenges only — Version 2, Phase C2's public Challenges
  /// tab for guests/members. Distinct from [fetchAllChallenges] rather
  /// than filtering client-side so the query itself is the same shape
  /// as [fetchAllChallenges] (`is_active = TRUE` added), matching the
  /// published-vs-all split TrekRepository already has
  /// (publishedTreks/adminAllTreks).
  Future<List<Challenge>> fetchActiveChallenges();

  /// A single challenge by id — used both by the admin edit form to
  /// prefill and by Challenge Detail's public view.
  Future<Challenge?> fetchChallengeById(String id);

  /// Creates a challenge (starts inactive/draft — see the migration's
  /// `is_active` default) together with all 4 tier thresholds in one
  /// call — a challenge is never created without its tiers the way a
  /// product can be created without images yet.
  Future<Challenge> createChallenge({
    required String title,
    required String description,
    required ChallengeMetric metric,
    required ChallengeTimeWindow timeWindow,
    DateTime? startDate,
    DateTime? endDate,
    String? icon,
    required Map<ChallengeTier, double> tierThresholds,
    int pointValue = 50,
  });

  /// Updates a challenge's fields AND reconciles its 4 tier
  /// thresholds (upsert by the `UNIQUE (challenge_id, tier)`
  /// constraint — every tier already exists from creation, so this is
  /// always an update in practice, never an insert, but upsert keeps
  /// this correct even against a pre-this-phase row that somehow has
  /// fewer than 4).
  Future<void> updateChallenge({
    required String id,
    required String title,
    required String description,
    required ChallengeMetric metric,
    required ChallengeTimeWindow timeWindow,
    DateTime? startDate,
    DateTime? endDate,
    String? icon,
    required Map<ChallengeTier, double> tierThresholds,
    int pointValue = 50,
  });

  /// Deletes the challenge row. `challenge_tiers` rows cascade
  /// automatically (FK ON DELETE CASCADE) — nothing else to clean up
  /// (unlike products/treks, challenges have no Storage objects).
  Future<void> deleteChallenge(String id);

  Future<void> setActive(String id, bool isActive);

  /// The signed-in user's own live-computed progress across every
  /// active challenge — wraps `get_my_challenge_progress()`. No
  /// challenge-id or user-id parameter: the function reads auth.uid()
  /// internally, so there is no way to call this for anyone but
  /// yourself — see the migration's doc for why that's the entire
  /// security model here rather than an RLS policy.
  Future<List<ChallengeProgress>> fetchMyProgress();

  /// Every (challenge, tier) the signed-in user has actually reached,
  /// with the real date it was reached — wraps
  /// `get_my_challenge_tier_history()`. Same no-parameter security
  /// model as [fetchMyProgress]. Powers Personal Challenge History
  /// (Version 2, Phase C2) and the completion-animation "newly
  /// achieved" detection (see ChallengeCelebrationTracker) — the same
  /// live-computed data serves both, no separate stored log.
  Future<List<ChallengeTierAchievement>> fetchMyTierHistory();

  /// Ranks every leaderboard-visible user by their progress on
  /// [challengeId] — wraps `get_challenge_leaderboard()` (Version 2,
  /// Phase C3). Safe to call as a guest (read-only browsing, same as
  /// [fetchActiveChallenges]); the RPC itself never returns anything
  /// beyond display name/rank/score for anyone, caller included — see
  /// 0025_leaderboard.sql's doc for why that's enforced in the
  /// function body, not just by what this method happens to select.
  Future<List<LeaderboardEntry>> fetchLeaderboard(String challengeId);

  // ── Phase 21: Enrollment methods ─────────────────────────────────

  /// Enrolls the signed-in user in a challenge. Idempotent — calling
  /// again for an already-enrolled challenge returns the existing row
  /// without awarding the bonus a second time. Returns the enrollment row.
  Future<ChallengeEnrollment> enrollInChallenge(String challengeId);

  /// Removes the signed-in user's enrollment. The 10-pt enrollment
  /// bonus is NOT reversed. Returns silently if not enrolled.
  Future<void> unenrollFromChallenge(String challengeId);

  /// Whether the signed-in user is enrolled in [challengeId]. Returns
  /// false for a guest (no session → no enrollment rows).
  Future<bool> isEnrolled(String challengeId);

  /// All of the signed-in user's current enrollments. Empty for a guest.
  Future<List<ChallengeEnrollment>> fetchMyEnrollments();

  /// Total count of enrolled participants for [challengeId].
  /// Safe to call as a guest.
  Future<int> fetchParticipantCount(String challengeId);

  /// Top [limit] enrolled participants ordered by live score, with
  /// total_points and level for the level badge display.
  Future<List<ChallengeTopParticipant>> fetchTopParticipants(
    String challengeId, {
    int limit = 10,
  });

  /// Active challenges where start_date > today, ordered by start_date
  /// ascending, limited to 3. Used for the Upcoming Challenges section
  /// on My Challenges.
  Future<List<Challenge>> fetchUpcomingChallenges({int limit = 3});

  /// Active challenges ordered by enrollment count descending — the
  /// Popular Challenges section on Explore. Uses a subquery count rather
  /// than a stored counter; fine at this project's scale.
  Future<List<Challenge>> fetchPopularChallenges({int limit = 5});

  /// Phase 24: awards `challenge_completed` points for every challenge
  /// in [challenges] where [progressList] shows [enrolledChallengeIds]
  /// has reached platinum, once per (user, challenge) — see
  /// `triggerChallengeCompletedPointsAward`'s doc for the exact rule.
  /// Fire-and-forget; failures are logged, not thrown.
  Future<void> maybeAwardChallengeCompletedPoints({
    required String userId,
    required List<Challenge> challenges,
    required List<ChallengeProgress> progressList,
    required Set<String> enrolledChallengeIds,
  });
}
