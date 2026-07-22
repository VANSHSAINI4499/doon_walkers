/// Maps to the `challenge_metric` enum in Postgres (`total_distance_km`,
/// `trek_count`) — see 0022_challenges.sql.
///
/// Elevation-gain challenges are explicitly deferred (Version 2, Phase
/// C1 scope decision) — treks only track max altitude, not real
/// elevation gain, which isn't the same thing. Only these two metrics
/// exist; adding a third later is a schema/enum change, not something
/// this app layer needs to special-case anywhere.
///
/// Unlike [ChallengeTier] this can NOT use `.name` to round-trip: Dart
/// identifiers are lowerCamelCase while the Postgres labels are
/// snake_case, so `totalDistanceKm` != `total_distance_km` — same
/// situation as `GenderType`, mapped explicitly in both directions.
enum ChallengeMetric {
  totalDistanceKm,
  trekCount;

  static ChallengeMetric fromString(String? value) => switch (value) {
    'total_distance_km' => ChallengeMetric.totalDistanceKm,
    'trek_count' => ChallengeMetric.trekCount,
    _ => ChallengeMetric.trekCount, // column is NOT NULL; arbitrary safe fallback
  };

  String toDbString() => switch (this) {
    ChallengeMetric.totalDistanceKm => 'total_distance_km',
    ChallengeMetric.trekCount => 'trek_count',
  };

  String get label => switch (this) {
    ChallengeMetric.totalDistanceKm => 'Total Distance (km)',
    ChallengeMetric.trekCount => 'Trek Count',
  };

  /// How a raw numeric progress value should read for this metric —
  /// e.g. "3" for trek_count vs "42.5 km" for total_distance_km. Used
  /// by the admin form/list; a future C2 progress UI would use the
  /// same formatting.
  String formatValue(double value) => switch (this) {
    ChallengeMetric.trekCount => value.toStringAsFixed(0),
    ChallengeMetric.totalDistanceKm =>
      '${value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2)} km',
  };
}

/// Maps to the `challenge_time_window` enum (`all_time`, `monthly`,
/// `custom_range`) — see 0022_challenges.sql. Same snake_case-mismatch
/// reasoning as [ChallengeMetric].
enum ChallengeTimeWindow {
  allTime,
  monthly,
  customRange;

  static ChallengeTimeWindow fromString(String? value) => switch (value) {
    'all_time' => ChallengeTimeWindow.allTime,
    'monthly' => ChallengeTimeWindow.monthly,
    'custom_range' => ChallengeTimeWindow.customRange,
    _ => ChallengeTimeWindow.allTime, // matches the DB column default
  };

  String toDbString() => switch (this) {
    ChallengeTimeWindow.allTime => 'all_time',
    ChallengeTimeWindow.monthly => 'monthly',
    ChallengeTimeWindow.customRange => 'custom_range',
  };

  String get label => switch (this) {
    ChallengeTimeWindow.allTime => 'All Time',
    ChallengeTimeWindow.monthly => 'This Month',
    ChallengeTimeWindow.customRange => 'Custom Date Range',
  };
}

/// Maps 1-to-1 with the `challenge_tier` enum (`bronze`, `silver`,
/// `gold`, `platinum`) — see 0022_challenges.sql. Unlike
/// [ChallengeMetric]/[ChallengeTimeWindow], every value is already a
/// single lowercase word, so `.name` round-trips safely — same
/// convention as `TrekDifficulty`/`MediaType`/`MerchInquiryStatus`.
///
/// Declared low-to-high — [ChallengeTier.values] IS the tier ordering,
/// relied on by the admin form's "thresholds must strictly increase"
/// validation rather than a separate rank field.
enum ChallengeTier {
  bronze,
  silver,
  gold,
  platinum;

  static ChallengeTier fromString(String? value) {
    return ChallengeTier.values.firstWhere(
      (t) => t.name == value,
      orElse: () => ChallengeTier.bronze,
    );
  }

  String toDbString() => name;

  String get label => switch (this) {
    ChallengeTier.bronze => 'Bronze',
    ChallengeTier.silver => 'Silver',
    ChallengeTier.gold => 'Gold',
    ChallengeTier.platinum => 'Platinum',
  };
}

/// A single tier's threshold for one challenge — a row in
/// `public.challenge_tiers`. A challenge always has exactly one of
/// each of the 4 [ChallengeTier] values, set together by the admin
/// form — never a partial/variable subset the way a product's sizes
/// are.
class ChallengeTierThreshold {
  final String id;
  final String challengeId;
  final ChallengeTier tier;
  final double thresholdValue;

  const ChallengeTierThreshold({
    required this.id,
    required this.challengeId,
    required this.tier,
    required this.thresholdValue,
  });
}

/// Core domain representation of a row in `public.challenges`, with
/// its nested [tiers] (one-to-many, fetched via a joined query — see
/// ChallengeRepository).
class Challenge {
  final String id;
  final String title;
  final String description;
  final ChallengeMetric metric;
  final ChallengeTimeWindow timeWindow;

  /// Applies across every [timeWindow], not just customRange — see
  /// 0022_challenges.sql's doc for why this is one uniform filtering
  /// rule ("the earliest/latest a trek can count") rather than three
  /// window-specific special cases. Required (enforced by a DB CHECK)
  /// when [timeWindow] is customRange; optional everywhere else.
  final DateTime? startDate;
  final DateTime? endDate;

  /// A small known identifier string (e.g. 'hiking', 'terrain',
  /// 'trophy') the app maps to a Material icon — see
  /// `ChallengeIcon.forKey`. Not a free-form image reference this
  /// phase (no Storage bucket needed for a tab that doesn't render
  /// until C2); a future phase could repoint this same TEXT column at
  /// an image URL instead without a schema change.
  final String? icon;

  /// Defaults false — a challenge stays a draft (admin-only visible)
  /// until explicitly activated, same "safe by default" contract as
  /// treks.is_published / products.is_active.
  final bool isActive;

  final DateTime createdAt;

  final List<ChallengeTierThreshold> tiers;

  const Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.metric,
    required this.timeWindow,
    this.startDate,
    this.endDate,
    this.icon,
    required this.isActive,
    required this.createdAt,
    this.tiers = const [],
  });

  /// The 4 tiers in ascending order (bronze → platinum), regardless of
  /// what order they came back from the query in.
  List<ChallengeTierThreshold> get tiersAscending {
    final sorted = [...tiers];
    sorted.sort((a, b) => ChallengeTier.values.indexOf(a.tier).compareTo(
          ChallengeTier.values.indexOf(b.tier),
        ));
    return sorted;
  }
}
