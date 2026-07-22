import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';

/// Data model representing a row in `public.challenge_tiers`, extending
/// [ChallengeTierThreshold] with JSON deserialization.
class ChallengeTierThresholdModel extends ChallengeTierThreshold {
  const ChallengeTierThresholdModel({
    required super.id,
    required super.challengeId,
    required super.tier,
    required super.thresholdValue,
  });

  factory ChallengeTierThresholdModel.fromJson(Map<String, dynamic> json) {
    return ChallengeTierThresholdModel(
      id: json['id'] as String,
      challengeId: json['challenge_id'] as String,
      tier: ChallengeTier.fromString(json['tier'] as String?),
      thresholdValue: switch (json['threshold_value']) {
        null => 0,
        final num n => n.toDouble(),
        final Object v => double.tryParse(v.toString()) ?? 0,
      },
    );
  }
}

/// Data model representing a row in `public.challenges`, extending
/// [Challenge] with JSON deserialization — including its embedded
/// `challenge_tiers(*)` join (see ChallengeRepositoryImpl's
/// `.select()` shape).
class ChallengeModel extends Challenge {
  const ChallengeModel({
    required super.id,
    required super.title,
    required super.description,
    required super.metric,
    required super.timeWindow,
    super.startDate,
    super.endDate,
    super.icon,
    required super.isActive,
    required super.createdAt,
    super.tiers,
  });

  factory ChallengeModel.fromJson(Map<String, dynamic> json) {
    final tierRows = (json['challenge_tiers'] as List?) ?? const [];

    return ChallengeModel(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      metric: ChallengeMetric.fromString(json['metric'] as String?),
      timeWindow: ChallengeTimeWindow.fromString(json['time_window'] as String?),
      // Postgres `date` arrives as an ISO date string ("2026-07-01"),
      // parseable directly by DateTime.parse.
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date'] as String) : null,
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date'] as String) : null,
      icon: json['icon'] as String?,
      isActive: json['is_active'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      tiers: tierRows
          .map((row) => ChallengeTierThresholdModel.fromJson(row as Map<String, dynamic>))
          .toList(),
    );
  }
}
