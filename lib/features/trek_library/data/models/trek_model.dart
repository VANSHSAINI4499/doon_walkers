import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';

/// Data model representing a row in `public.treks`, extending [Trek]
/// with JSON deserialization from a Supabase/PostgREST row.
class TrekModel extends Trek {
  const TrekModel({
    required super.id,
    required super.title,
    required super.description,
    required super.difficulty,
    super.distanceKm,
    super.durationDays,
    super.altitudeM,
    super.bestSeason,
    super.thingsToCarry,
    super.googleMapLink,
    super.coverImage,
    required super.isPublished,
    required super.createdAt,
  });

  factory TrekModel.fromJson(Map<String, dynamic> json) {
    return TrekModel(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      difficulty: TrekDifficulty.fromString(json['difficulty'] as String?),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      durationDays: (json['duration_days'] as num?)?.toInt(),
      altitudeM: (json['altitude_m'] as num?)?.toInt(),
      bestSeason: json['best_season'] as String?,
      thingsToCarry: json['things_to_carry'] as String?,
      googleMapLink: json['google_map_link'] as String?,
      coverImage: json['cover_image'] as String?,
      isPublished: json['is_published'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
