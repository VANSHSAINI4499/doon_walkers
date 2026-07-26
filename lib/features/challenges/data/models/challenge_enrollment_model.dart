import 'package:doon_walkers/features/challenges/domain/entities/challenge_enrollment.dart';

/// Data model for a row in `public.challenge_enrollments`.
class ChallengeEnrollmentModel extends ChallengeEnrollment {
  const ChallengeEnrollmentModel({
    required super.id,
    required super.challengeId,
    required super.userId,
    required super.enrolledAt,
  });

  factory ChallengeEnrollmentModel.fromJson(Map<String, dynamic> json) {
    return ChallengeEnrollmentModel(
      id: json['id'] as String,
      challengeId: json['challenge_id'] as String,
      userId: json['user_id'] as String,
      enrolledAt: json['enrolled_at'] != null
          ? DateTime.parse(json['enrolled_at'] as String)
          : DateTime.now(),
    );
  }
}
