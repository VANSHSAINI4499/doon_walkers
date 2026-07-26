import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';

/// The metric families Explore's filter chips offer.
///
/// Deliberately **four groups over the real seven metrics**, not one chip
/// per enum value. `dailySteps`/`weeklySteps`/`monthlySteps` all sum the
/// same `daily_activity_summary.steps` column (see [ChallengeMetric]'s
/// doc) — they exist as separate enum values only as admin vocabulary, so
/// three separate "Steps" chips would be three chips filtering the same
/// thing.
///
/// Every group maps to metrics the engine actually computes. There is no
/// hydration chip, no time-in-nature chip, no mindfulness chip: no data
/// source exists for any of them, so a chip would return an empty list
/// forever.
///
/// [trekCount]/[totalDistanceKm] are folded into [distance] and [trek]
/// respectively rather than dropped — no challenge currently uses them
/// post-pivot, but they are still valid enum values an admin could pick,
/// and a challenge that matched no chip would be unreachable through
/// filtering.
enum ChallengeMetricFilter {
  steps,
  distance,
  calories,
  streak,
  trek;

  String get label => switch (this) {
    ChallengeMetricFilter.steps => 'Steps',
    ChallengeMetricFilter.distance => 'Distance',
    ChallengeMetricFilter.calories => 'Calories',
    ChallengeMetricFilter.streak => 'Streak',
    ChallengeMetricFilter.trek => 'Treks',
  };

  bool matches(ChallengeMetric metric) => switch (this) {
    ChallengeMetricFilter.steps =>
      metric == ChallengeMetric.dailySteps ||
          metric == ChallengeMetric.weeklySteps ||
          metric == ChallengeMetric.monthlySteps,
    ChallengeMetricFilter.distance =>
      metric == ChallengeMetric.dailyDistanceKm ||
          metric == ChallengeMetric.totalDistanceKm,
    ChallengeMetricFilter.calories => metric == ChallengeMetric.caloriesBurned,
    ChallengeMetricFilter.streak => metric == ChallengeMetric.activeStreakDays,
    ChallengeMetricFilter.trek => metric == ChallengeMetric.trekCount,
  };
}

/// Filters [challenges] by a free-text [query] and an optional set of
/// [metricFilters].
///
/// Pure, and separated from the widget so the matching rules have direct
/// test coverage — the failure modes here are quiet ones (a stray filter
/// that hides everything, a case-sensitive search that finds nothing) that
/// look like "no challenges exist" rather than like a bug.
///
/// Rules:
///  - [query] is trimmed, case-insensitive, and matched against title
///    **and** description — someone searching "steps" should find a
///    challenge called "October Push" whose description mentions steps.
///  - An empty [metricFilters] means "no metric filter", not "match
///    nothing" — that is the default state of the chip row.
///  - Multiple filters are OR'd: Steps + Distance shows both, which is
///    what a row of independently-toggleable chips implies.
///  - Ordering is preserved from the input, so the caller stays in
///    control of sort.
List<Challenge> filterChallenges(
  List<Challenge> challenges, {
  String query = '',
  Set<ChallengeMetricFilter> metricFilters = const {},
}) {
  final needle = query.trim().toLowerCase();

  return challenges.where((challenge) {
    if (metricFilters.isNotEmpty &&
        !metricFilters.any((f) => f.matches(challenge.metric))) {
      return false;
    }

    if (needle.isEmpty) return true;

    return challenge.title.toLowerCase().contains(needle) ||
        challenge.description.toLowerCase().contains(needle);
  }).toList();
}
