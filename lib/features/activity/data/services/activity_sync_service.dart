import 'package:doon_walkers/features/activity/domain/repositories/activity_provider.dart';
import 'package:doon_walkers/features/activity/domain/repositories/activity_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Outcome of a sync attempt — drives ActivityPermissionBanner's state
/// without it needing to know provider-specific detail.
enum ActivitySyncOutcome {
  /// Synced (possibly zero new days — still a success, just nothing new).
  success,

  /// This device has no usable provider right now (not installed /
  /// unsupported) — [ActivityProvider.openProviderSettings] is the
  /// remediation path.
  providerUnavailable,

  /// Provider is available but permission hasn't been granted.
  permissionDenied,

  /// A guest — nothing to sync to (no signed-in user's row to write).
  notSignedIn,

  /// Something else went wrong (network, etc.) — see debugPrint output.
  error,
}

/// Reads recent days from whichever [ActivityProvider] is active and
/// upserts them into `daily_activity_summary` via [ActivityRepository].
/// The Challenge engine never calls this or a provider directly — it
/// only ever reads the table this writes to.
///
/// Deliberately provider-agnostic: this class is written entirely
/// against the [ActivityProvider] interface, never against
/// HealthConnectProvider specifically, so a future second provider
/// (Apple Health, etc.) needs zero changes here — only a new
/// [ActivityProvider] implementation and whatever picks which one is
/// "active" for the current platform.
class ActivitySyncService {
  ActivitySyncService(this._provider, this._repository);

  final ActivityProvider _provider;
  final ActivityRepository _repository;

  /// How many trailing days to re-read on every sync. Deliberately more
  /// than 1 (not just "today") — a sync that only ever reads today
  /// would never backfill a day the user simply hadn't opened the app
  /// on, and Health Connect data for a day can keep arriving after
  /// midnight (e.g. a workout still syncing from a paired device), so
  /// re-reading a short trailing window keeps yesterday's total honest
  /// even after the day has technically ended.
  static const _lookbackDays = 7;

  bool _isSyncing = false;

  Future<ActivitySyncOutcome> sync() async {
    // Checked first, before touching the provider at all — a guest has
    // no row to sync to, and shouldn't be prompted for a Health Connect
    // permission for a feature they can't use yet anyway.
    if (Supabase.instance.client.auth.currentUser == null) {
      return ActivitySyncOutcome.notSignedIn;
    }

    if (_isSyncing) return ActivitySyncOutcome.success;
    _isSyncing = true;
    try {
      final availability = await _provider.checkAvailability();
      if (availability != ActivityAvailability.available) {
        return ActivitySyncOutcome.providerUnavailable;
      }

      if (!await _provider.hasPermission()) {
        return ActivitySyncOutcome.permissionDenied;
      }

      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: _lookbackDays - 1));
      final activity = await _provider.readDailyActivity(start: start, end: now);

      await _repository.upsertDailyActivity(activity);
      return ActivitySyncOutcome.success;
    } catch (e, st) {
      debugPrint('ActivitySyncService: sync failed: $e');
      debugPrint('$st');
      return ActivitySyncOutcome.error;
    } finally {
      _isSyncing = false;
    }
  }
}
