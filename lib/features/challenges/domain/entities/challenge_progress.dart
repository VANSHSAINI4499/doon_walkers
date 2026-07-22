import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';

/// The signed-in user's live-computed standing on one challenge — a
/// row returned by the `get_my_challenge_progress()` RPC (see
/// 0022_challenges.sql), never a stored/maintained row of its own.
///
/// [currentTier] is null when the user hasn't reached even the lowest
/// (bronze) tier's threshold yet — not an error state, just "no tier
/// achieved" (0 is a completely normal value for
/// [ChallengeMetric.trekCount] especially).
class ChallengeProgress {
  final String challengeId;
  final double currentValue;
  final ChallengeTier? currentTier;

  const ChallengeProgress({
    required this.challengeId,
    required this.currentValue,
    this.currentTier,
  });
}
