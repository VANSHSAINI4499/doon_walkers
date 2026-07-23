/// Maps to the `challenge_metric` enum in Postgres — see
/// 0022_challenges.sql (original trek-based metrics) and
/// 0026_fitness_activity_schema.sql (Version 2, Challenges Module
/// pivot: daily fitness activity, sourced from Health Connect via
/// ActivityProvider → ActivitySyncService → `daily_activity_summary`).
///
/// [totalDistanceKm]/[trekCount] are KEPT (not removed — Postgres
/// enum values can't be cheaply dropped, and no challenge currently
/// uses them after the pivot's cleanup deleted the 4 trek-based
/// challenges) but are no longer the primary direction; every new
/// challenge should use one of the fitness metrics below.
///
/// [dailySteps]/[weeklySteps]/[monthlySteps] all sum the SAME
/// `daily_activity_summary.steps` column — they exist as separate
/// enum values (rather than one `steps` metric) purely as the
/// vocabulary an admin picks from; which one actually applies is
/// [Challenge.timeWindow], exactly like [totalDistanceKm]/[trekCount]
/// were already orthogonal to their window. The admin form pairs each
/// with its natural window (e.g. dailySteps ↔ daily) by convention,
/// not a DB constraint — same "trust the admin form" pattern as tier
/// thresholds needing to strictly increase.
///
/// [activeStreakDays] is fundamentally different from every other
/// metric here: it is NOT a windowed sum. It's the user's current run
/// of consecutive CALENDAR DAYS with at least one active day (any
/// `daily_activity_summary` row with steps > 0) — see
/// get_my_streak()'s doc (0024_streaks.sql) for the analogous
/// month-granular version this generalizes from, and note this is
/// entirely separate from that Profile-level trekking streak: this
/// one is a per-challenge fitness metric, that one is attendance-based
/// and untouched by this pivot.
///
/// Unlike [ChallengeTier] this can NOT use `.name` to round-trip: Dart
/// identifiers are lowerCamelCase while the Postgres labels are
/// snake_case, so `totalDistanceKm` != `total_distance_km` — same
/// situation as `GenderType`, mapped explicitly in both directions.
enum ChallengeMetric {
  totalDistanceKm,
  trekCount,
  dailySteps,
  weeklySteps,
  monthlySteps,
  dailyDistanceKm,
  caloriesBurned,
  activeStreakDays;

  static ChallengeMetric fromString(String? value) => switch (value) {
    'total_distance_km' => ChallengeMetric.totalDistanceKm,
    'trek_count' => ChallengeMetric.trekCount,
    'daily_steps' => ChallengeMetric.dailySteps,
    'weekly_steps' => ChallengeMetric.weeklySteps,
    'monthly_steps' => ChallengeMetric.monthlySteps,
    'daily_distance_km' => ChallengeMetric.dailyDistanceKm,
    'calories_burned' => ChallengeMetric.caloriesBurned,
    'active_streak_days' => ChallengeMetric.activeStreakDays,
    _ => ChallengeMetric.dailySteps, // column is NOT NULL; arbitrary safe fallback
  };

  String toDbString() => switch (this) {
    ChallengeMetric.totalDistanceKm => 'total_distance_km',
    ChallengeMetric.trekCount => 'trek_count',
    ChallengeMetric.dailySteps => 'daily_steps',
    ChallengeMetric.weeklySteps => 'weekly_steps',
    ChallengeMetric.monthlySteps => 'monthly_steps',
    ChallengeMetric.dailyDistanceKm => 'daily_distance_km',
    ChallengeMetric.caloriesBurned => 'calories_burned',
    ChallengeMetric.activeStreakDays => 'active_streak_days',
  };

  String get label => switch (this) {
    ChallengeMetric.totalDistanceKm => 'Total Trek Distance (km)',
    ChallengeMetric.trekCount => 'Trek Count',
    ChallengeMetric.dailySteps => 'Steps',
    ChallengeMetric.weeklySteps => 'Steps',
    ChallengeMetric.monthlySteps => 'Steps',
    ChallengeMetric.dailyDistanceKm => 'Distance (km)',
    ChallengeMetric.caloriesBurned => 'Calories Burned',
    ChallengeMetric.activeStreakDays => 'Activity Streak (days)',
  };

  /// Plain-language "what counts" blurb for Challenge Detail — Version
  /// 2, Phase C2 (extended for the fitness pivot). Deliberately
  /// generic wording, not tied to any particular challenge, so a new
  /// metric added later only needs a new switch arm here, never a
  /// per-challenge string.
  String get explanation => switch (this) {
    ChallengeMetric.totalDistanceKm =>
      'Based on the total distance of every trek you\'ve attended.',
    ChallengeMetric.trekCount => 'Based on the number of treks you\'ve attended.',
    ChallengeMetric.dailySteps ||
    ChallengeMetric.weeklySteps ||
    ChallengeMetric.monthlySteps =>
      'Based on your step count, synced from Health Connect.',
    ChallengeMetric.dailyDistanceKm =>
      'Based on the distance you\'ve walked or run, synced from Health Connect.',
    ChallengeMetric.caloriesBurned =>
      'Based on calories burned, synced from Health Connect.',
    ChallengeMetric.activeStreakDays =>
      'Based on your current run of consecutive days with any recorded activity.',
  };

  /// A short footnote clarifying what "counts" at a more mechanical
  /// level than [explanation] — the trek metrics' attendance rule vs.
  /// the fitness metrics' sync source. Shown on Challenge Detail below
  /// [explanation]/the time-window explanation.
  String get footnote => switch (this) {
    ChallengeMetric.totalDistanceKm || ChallengeMetric.trekCount =>
      'A trek counts as attended once its date has passed and your '
          'registration wasn\'t cancelled.',
    ChallengeMetric.dailySteps ||
    ChallengeMetric.weeklySteps ||
    ChallengeMetric.monthlySteps ||
    ChallengeMetric.dailyDistanceKm ||
    ChallengeMetric.caloriesBurned ||
    ChallengeMetric.activeStreakDays =>
      'Synced from Health Connect on your device — grant permission and '
          'sync from the Challenges tab if your progress looks out of date.',
  };

  /// How a raw numeric progress value should read for this metric —
  /// e.g. "3" for trek_count vs "42.5 km" for total_distance_km. Used
  /// by the admin form/list and the member-facing progress bar.
  String formatValue(double value) => switch (this) {
    ChallengeMetric.trekCount => value.toStringAsFixed(0),
    ChallengeMetric.totalDistanceKm || ChallengeMetric.dailyDistanceKm =>
      '${value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2)} km',
    ChallengeMetric.dailySteps || ChallengeMetric.weeklySteps || ChallengeMetric.monthlySteps =>
      '${value.toStringAsFixed(0)} steps',
    ChallengeMetric.caloriesBurned => '${value.toStringAsFixed(0)} kcal',
    ChallengeMetric.activeStreakDays =>
      '${value.toStringAsFixed(0)} day${value == 1 ? '' : 's'}',
  };
}

/// Maps to the `challenge_time_window` enum in Postgres — see
/// 0022_challenges.sql (`all_time`, `monthly`, `custom_range`) and
/// 0026_fitness_activity_schema.sql (`daily`, `weekly` — added for
/// the Challenges Module fitness pivot, needed for "steps today" /
/// "steps this week" style challenges that didn't exist in the
/// trek-only design). Same snake_case-mismatch reasoning as
/// [ChallengeMetric]. Ignored entirely by [ChallengeMetric.activeStreakDays]
/// — a streak is inherently "as of today," not a period sum.
enum ChallengeTimeWindow {
  allTime,
  monthly,
  weekly,
  daily,
  customRange;

  static ChallengeTimeWindow fromString(String? value) => switch (value) {
    'all_time' => ChallengeTimeWindow.allTime,
    'monthly' => ChallengeTimeWindow.monthly,
    'weekly' => ChallengeTimeWindow.weekly,
    'daily' => ChallengeTimeWindow.daily,
    'custom_range' => ChallengeTimeWindow.customRange,
    _ => ChallengeTimeWindow.allTime, // matches the DB column default
  };

  String toDbString() => switch (this) {
    ChallengeTimeWindow.allTime => 'all_time',
    ChallengeTimeWindow.monthly => 'monthly',
    ChallengeTimeWindow.weekly => 'weekly',
    ChallengeTimeWindow.daily => 'daily',
    ChallengeTimeWindow.customRange => 'custom_range',
  };

  String get label => switch (this) {
    ChallengeTimeWindow.allTime => 'All Time',
    ChallengeTimeWindow.monthly => 'This Month',
    ChallengeTimeWindow.weekly => 'This Week',
    ChallengeTimeWindow.daily => 'Today',
    ChallengeTimeWindow.customRange => 'Custom Date Range',
  };

  /// Plain-language companion to [ChallengeMetric.explanation] for
  /// Challenge Detail — describes WHICH activity counts, not what it's
  /// measured by. [Challenge.customRange] callers should still show the
  /// actual start/end dates alongside this; this string alone doesn't
  /// carry them.
  String get explanation => switch (this) {
    ChallengeTimeWindow.allTime => 'Counts everything you\'ve ever recorded.',
    ChallengeTimeWindow.monthly => 'Only counts activity from the current calendar month.',
    ChallengeTimeWindow.weekly => 'Only counts activity from the current week (Monday to Sunday).',
    ChallengeTimeWindow.daily => 'Only counts activity from today.',
    ChallengeTimeWindow.customRange =>
      'Only counts activity within this challenge\'s date range.',
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
