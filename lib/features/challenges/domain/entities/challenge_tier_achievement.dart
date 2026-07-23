import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';

/// One (challenge, tier) the signed-in user has actually reached, with
/// the real date it was reached — a row from
/// `get_my_challenge_tier_history()`, computed live from the same
/// attended-treks data as [Challenge]'s progress, not a separately
/// maintained achievement log. See that RPC's doc (0023_challenge_
/// tier_history.sql) for how the date is derived without any stored
/// state: the date of the attended trek whose running cumulative value
/// first met the tier's threshold.
class ChallengeTierAchievement {
  final String challengeId;
  final ChallengeTier tier;
  final DateTime achievedAt;

  const ChallengeTierAchievement({
    required this.challengeId,
    required this.tier,
    required this.achievedAt,
  });
}
