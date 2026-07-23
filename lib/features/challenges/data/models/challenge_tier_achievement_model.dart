import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_tier_achievement.dart';

/// Data model for one row returned by the
/// `get_my_challenge_tier_history()` RPC.
class ChallengeTierAchievementModel extends ChallengeTierAchievement {
  const ChallengeTierAchievementModel({
    required super.challengeId,
    required super.tier,
    required super.achievedAt,
  });

  factory ChallengeTierAchievementModel.fromJson(Map<String, dynamic> json) {
    return ChallengeTierAchievementModel(
      challengeId: json['challenge_id'] as String,
      // Always present here (unlike current_tier on the progress RPC) —
      // every row this RPC returns represents a tier that WAS reached,
      // so ChallengeTier.fromString's "unknown defaults to bronze"
      // fallback is safe: it only ever guards against a malformed row,
      // never masks a genuine "no tier" case the way it would on the
      // progress RPC's nullable current_tier.
      tier: ChallengeTier.fromString(json['tier'] as String?),
      achievedAt: DateTime.parse(json['achieved_at'] as String),
    );
  }
}
