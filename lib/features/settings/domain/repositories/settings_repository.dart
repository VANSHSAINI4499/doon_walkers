import 'package:doon_walkers/features/settings/domain/entities/app_settings.dart';

/// Abstract interface for reading community settings.
///
/// Write access is intentionally not part of this interface — settings
/// are admin-write-only at the database level (RLS, 0002_role_policies.sql)
/// and the admin editor UI is out of scope until Phase 9.
abstract class SettingsRepository {
  /// Fetches the full settings table as an [AppSettings] snapshot.
  ///
  /// One-shot fetch, not a live stream — see [settingsProvider]'s doc
  /// for why this table isn't on Realtime.
  Future<AppSettings> fetchSettings();
}
