import 'package:doon_walkers/features/activity/domain/entities/daily_activity.dart';

/// Whether this device can currently supply activity data through this
/// [ActivityProvider], and if not, what the user can do about it.
///
/// Deliberately just two states rather than a finer-grained "not
/// installed" vs. "OS too old" split: Health Connect's own SDK status
/// API (see HealthConnectProvider) doesn't reliably distinguish those
/// either — both report as "unavailable," and [installHealthConnect]-
/// style remediation (send the user to the Play Store) is the right
/// action either way, since the store listing itself handles device
/// compatibility.
enum ActivityAvailability {
  /// Ready to request permission and read data.
  available,

  /// Not usable right now — the provider's data source either isn't
  /// installed, needs an update, or isn't supported on this device.
  /// [ActivityProvider.openProviderSettings] is the remediation path.
  unavailable,
}

/// Abstraction over "a source of daily fitness activity" — steps,
/// distance, calories. The Challenges engine (progress/tier-history/
/// leaderboard RPCs) never talks to this directly and never knows
/// which implementation is active; it only ever reads
/// `daily_activity_summary`, which [ActivitySyncService] populates
/// from whichever [ActivityProvider] is currently wired up.
///
/// [HealthConnectProvider] is the first (and, as of this phase, only)
/// real implementation, Android-only. A future Apple Health
/// implementation is a second class implementing this exact interface
/// — no engine or sync-service change required; see this project's
/// analysis doc from the Challenges Module pivot for the full
/// reasoning behind keeping this swappable rather than baking Health
/// Connect into the sync service directly.
abstract class ActivityProvider {
  /// A short, provider-specific identifier for logging/diagnostics
  /// (e.g. 'health_connect') — not shown to users.
  String get id;

  Future<ActivityAvailability> checkAvailability();

  /// Whether the necessary read permissions are already granted,
  /// without prompting.
  Future<bool> hasPermission();

  /// Prompts the user for whatever permissions this provider needs.
  /// Returns whether they were granted. Callers should check
  /// [checkAvailability] first — requesting permission on an
  /// unavailable provider throws.
  Future<bool> requestPermission();

  /// Reads daily activity for each calendar day in
  /// `[start, end]` (inclusive), one [DailyActivity] per day that has
  /// any data — days with nothing recorded are simply absent from the
  /// result, not returned as zero-valued entries.
  Future<List<DailyActivity>> readDailyActivity({
    required DateTime start,
    required DateTime end,
  });

  /// Opens whatever the user needs to install/update/enable this
  /// provider's data source (e.g. the Health Connect Play Store page).
  Future<void> openProviderSettings();
}
