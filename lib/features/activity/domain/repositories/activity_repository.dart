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

  /// The signed-in user's own rows from [from] (inclusive) onward,
  /// oldest first. Empty for a guest rather than throwing — every caller
  /// treats "no data" as a normal state.
  ///
  /// Added in Redesign 2.0 Phase 12 for the Challenges header's activity
  /// streak. Own-row only, straight through the table's existing
  /// `daily_activity_summary_select_own` policy — no RPC, because the
  /// caller is only ever asking about themselves.
  Future<List<DailyActivity>> fetchDailyActivitySince(DateTime from);

  /// The signed-in user's own rows in the inclusive range [from]..[to],
  /// oldest first. Empty for a guest.
  ///
  /// Added in Redesign 2.0 Phase 11 for the Activity dashboard's
  /// Day/Week/Month views. Both ends inclusive, matching
  /// `ActivityPeriod`'s convention.
  Future<List<DailyActivity>> fetchDailyActivityRange({
    required DateTime from,
    required DateTime to,
  });

  /// How the caller's step total for [month] ranks against every other
  /// tracking member, as a whole percentage — or null when it cannot be
  /// said (fewer than 5 people tracked that month, or the caller has no
  /// data for it).
  ///
  /// Wraps `get_my_activity_percentile()` (0035_activity_percentile.sql),
  /// which is SECURITY DEFINER and aggregate-only: it returns a single
  /// integer and never exposes another member's rows. This is the ONLY
  /// cross-user read in the activity feature — everything else is own-row
  /// straight through RLS.
  Future<int?> fetchActivityPercentile(DateTime month);
}
