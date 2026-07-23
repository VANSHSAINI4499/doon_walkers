import 'package:doon_walkers/features/activity/domain/entities/daily_activity.dart';

/// Abstract interface for reading/writing the signed-in user's own
/// `public.daily_activity_summary` rows — the table the Challenge
/// engine reads from (see ActivityProvider's doc for the full data
/// flow: device → ActivityProvider → ActivitySyncService → this table
/// → RPCs).
abstract class ActivityRepository {
  /// Upserts one row per [DailyActivity.date] for the signed-in user —
  /// a resync of an already-synced day always updates that day's row
  /// (`UNIQUE(user_id, date)`), never duplicates it.
  Future<void> upsertDailyActivity(List<DailyActivity> activity);

  /// The signed-in user's most recent `synced_at` across all rows, or
  /// null if nothing has ever been synced — drives the "last synced"
  /// freshness indicator in ActivityPermissionBanner.
  Future<DateTime?> fetchLastSyncedAt();
}
