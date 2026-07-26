/// One row in `public.challenge_enrollments` — a user's explicit opt-in
/// to a challenge. Added in Phase 21 (0038_challenge_enrollments.sql).
class ChallengeEnrollment {
  final String id;
  final String challengeId;
  final String userId;
  final DateTime enrolledAt;

  const ChallengeEnrollment({
    required this.id,
    required this.challengeId,
    required this.userId,
    required this.enrolledAt,
  });
}
