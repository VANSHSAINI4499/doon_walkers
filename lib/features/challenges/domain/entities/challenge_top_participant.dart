/// One row returned by `get_challenge_top_participants()` — an enrolled
/// user's live score + total points for display in the Top Participants
/// list on the Challenge Detail Overview tab. Phase 21.
class ChallengeTopParticipant {
  final String userId;
  final String displayName;

  /// Nullable — users without a profile photo show initials instead.
  final String? avatarUrl;

  /// Live challenge score (same source as get_challenge_leaderboard).
  final double score;

  /// Cumulative points from user_points.total_points — shown as a chip
  /// to display level progress alongside the challenge score.
  final int totalPoints;

  /// User's current level (1–8) from user_points.level.
  final int level;

  const ChallengeTopParticipant({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.score,
    required this.totalPoints,
    required this.level,
  });
}
