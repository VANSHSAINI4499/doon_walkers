/// One ranked row from `get_challenge_leaderboard()` — Version 2,
/// Phase C3. Deliberately carries nothing about the ranked user beyond
/// [displayName]: no id, no email, no phone — the RPC itself never
/// returns anything more (see 0025_leaderboard.sql's doc), so there is
/// nothing more this entity could carry even if it wanted to.
class LeaderboardEntry {
  final String displayName;
  final int rank;
  final double score;

  const LeaderboardEntry({required this.displayName, required this.rank, required this.score});
}
