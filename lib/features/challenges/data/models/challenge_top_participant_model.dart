import 'package:doon_walkers/features/challenges/domain/entities/challenge_top_participant.dart';

/// Data model for a row from `get_challenge_top_participants()` RPC.
class ChallengeTopParticipantModel extends ChallengeTopParticipant {
  const ChallengeTopParticipantModel({
    required super.userId,
    required super.displayName,
    super.avatarUrl,
    required super.score,
    required super.totalPoints,
    required super.level,
  });

  factory ChallengeTopParticipantModel.fromJson(Map<String, dynamic> json) {
    return ChallengeTopParticipantModel(
      userId: json['user_id'] as String,
      displayName: (json['display_name'] as String?) ?? 'Walker',
      avatarUrl: json['avatar_url'] as String?,
      score: switch (json['score']) {
        null => 0.0,
        final num n => n.toDouble(),
        final Object v => double.tryParse(v.toString()) ?? 0.0,
      },
      totalPoints: (json['total_points'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
    );
  }
}
