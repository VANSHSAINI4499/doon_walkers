/// Maps 1-to-1 with the `trek_difficulty` enum in Postgres
/// (`easy`, `moderate`, `hard`, `extreme`) — see 0001_baseline_schema.sql.
enum TrekDifficulty {
  easy,
  moderate,
  hard,
  extreme;

  /// Matches the Dart enum's identifier name exactly to the Postgres
  /// enum value — deliberately kept 1:1 so `.name` round-trips safely.
  static TrekDifficulty fromString(String? value) {
    return TrekDifficulty.values.firstWhere(
      (d) => d.name == value,
      orElse: () => TrekDifficulty.moderate, // matches the DB column default
    );
  }

  String toDbString() => name;

  String get label => switch (this) {
    TrekDifficulty.easy => 'Easy',
    TrekDifficulty.moderate => 'Moderate',
    TrekDifficulty.hard => 'Hard',
    TrekDifficulty.extreme => 'Extreme',
  };
}

/// Core domain representation of a row in `public.treks`.
class Trek {
  final String id;
  final String title;
  final String description;
  final TrekDifficulty difficulty;
  final double? distanceKm;
  final int? durationDays;
  final int? altitudeM;
  final String? bestSeason;
  final String? thingsToCarry;
  final String? googleMapLink;
  final String? coverImage;
  final bool isPublished;
  final DateTime createdAt;

  const Trek({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    this.distanceKm,
    this.durationDays,
    this.altitudeM,
    this.bestSeason,
    this.thingsToCarry,
    this.googleMapLink,
    this.coverImage,
    required this.isPublished,
    required this.createdAt,
  });
}
