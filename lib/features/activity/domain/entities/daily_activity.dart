/// One calendar day's aggregated fitness activity — the shape every
/// [ActivityProvider] implementation reads into, and what
/// ActivitySyncService upserts into `public.daily_activity_summary`.
///
/// Deliberately provider-agnostic: nothing here is Health-Connect-
/// specific, so a future Apple Health (or any other) provider produces
/// the exact same shape.
class DailyActivity {
  final DateTime date;
  final int steps;
  final double distanceKm;
  final double calories;

  const DailyActivity({
    required this.date,
    required this.steps,
    required this.distanceKm,
    required this.calories,
  });
}
