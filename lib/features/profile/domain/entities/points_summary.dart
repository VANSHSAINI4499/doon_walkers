/// The signed-in user's points/level standing, as computed server-side by
/// `get_my_points_summary()` (0039_points_history_and_enrollment_fix.sql).
///
/// [level] and the points-to-next-level figure are NEVER recomputed here —
/// the ladder lives in exactly one place, the `level_for_points()`/
/// `points_for_level()` SQL functions, and this entity just carries
/// whatever they returned.
class PointsSummary {
  const PointsSummary({
    required this.totalPoints,
    required this.level,
    required this.currentLevelFloor,
    required this.nextLevel,
    required this.pointsToNextLevel,
    required this.isMaxLevel,
  });

  final int totalPoints;
  final int level;

  /// `points_for_level(level)` — the total-points value at which [level]
  /// was first reached. Needed to normalize the progress bar to "how far
  /// through THIS level", not just total-vs-next-threshold.
  final int currentLevelFloor;

  /// Null when [isMaxLevel] is true.
  final int? nextLevel;

  /// Null when [isMaxLevel] is true.
  final int? pointsToNextLevel;
  final bool isMaxLevel;

  /// 0–1 progress through the current level, for [AppProgressBar]. 1.0 at
  /// max level (nothing further to fill toward).
  double get progressToNextLevel {
    if (isMaxLevel || nextLevel == null || pointsToNextLevel == null) {
      return 1.0;
    }
    final nextThreshold = totalPoints + pointsToNextLevel!;
    final span = nextThreshold - currentLevelFloor;
    if (span <= 0) return 1.0;
    return (totalPoints - currentLevelFloor) / span;
  }

  factory PointsSummary.fromRow(Map<String, dynamic> row) {
    return PointsSummary(
      totalPoints: (row['total_points'] as num?)?.toInt() ?? 0,
      level: (row['level'] as num?)?.toInt() ?? 1,
      currentLevelFloor: (row['current_level_floor'] as num?)?.toInt() ?? 0,
      nextLevel: (row['next_level'] as num?)?.toInt(),
      pointsToNextLevel: (row['points_to_next_level'] as num?)?.toInt(),
      isMaxLevel: row['is_max_level'] as bool? ?? false,
    );
  }

  /// A guest / no-session default — 0 points, level 1, 500 to level 2
  /// (matching real level-1 math). Only meaningful as a defensive
  /// fallback; `/profile` (and `/profile/points-history`) are both
  /// router-gated to signed-in members, so this should never actually
  /// reach the screen.
  static const guest = PointsSummary(
    totalPoints: 0,
    level: 1,
    currentLevelFloor: 0,
    nextLevel: 2,
    pointsToNextLevel: 500,
    isMaxLevel: false,
  );
}
