import 'package:doon_walkers/features/notifications/data/services/notification_read_tracker.dart';
import 'package:doon_walkers/features/notifications/domain/repositories/notification_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationReadMigrationService {
  static const String kReadsMigratedKey = 'reads_migrated_v1';

  final SharedPreferences _prefs;
  final NotificationReadTracker _tracker;
  final NotificationRepository _repository;

  NotificationReadMigrationService({
    required SharedPreferences prefs,
    required NotificationReadTracker tracker,
    required NotificationRepository repository,
  }) : _prefs = prefs,
       _tracker = tracker,
       _repository = repository;

  /// Performs a one-time migration of local SharedPreferences read IDs
  /// into the server-side `notification_reads` table.
  Future<void> migrateLocalReadsIfNeeded(String userId) async {
    final alreadyMigrated = _prefs.getBool(kReadsMigratedKey) ?? false;
    if (alreadyMigrated) return;

    try {
      final localReadIds = _tracker.readIds(userId);
      if (localReadIds.isNotEmpty) {
        for (final id in localReadIds) {
          await _repository.markAsRead(id);
        }
        await _tracker.clear(userId);
      }
      await _prefs.setBool(kReadsMigratedKey, true);
    } catch (_) {
      // Retry on next app start if network fails
    }
  }
}
