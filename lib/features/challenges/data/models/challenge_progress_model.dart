import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_progress.dart';

/// Data model representing one row returned by the
/// `get_my_challenge_progress()` RPC, extending [ChallengeProgress]
/// with JSON deserialization.
class ChallengeProgressModel extends ChallengeProgress {
  const ChallengeProgressModel({
    required super.challengeId,
    required super.currentValue,
    super.currentTier,
  });

  factory ChallengeProgressModel.fromJson(Map<String, dynamic> json) {
    return ChallengeProgressModel(
      challengeId: json['challenge_id'] as String,
      currentValue: switch (json['current_value']) {
        null => 0,
        final num n => n.toDouble(),
        final Object v => double.tryParse(v.toString()) ?? 0,
      },
      // Absent/null when the user hasn't reached bronze yet — not a
      // parsing fallback, a genuine "no tier" state. Does NOT use
      // ChallengeTier.fromString here since that defaults unknown/null
      // to bronze, which would be wrong here (would wrongly claim
      // "bronze achieved" for someone at 0 progress).
      currentTier: json['current_tier'] != null
          ? ChallengeTier.values.firstWhere(
              (t) => t.name == json['current_tier'],
              orElse: () => ChallengeTier.bronze,
            )
          : null,
    );
  }
}
