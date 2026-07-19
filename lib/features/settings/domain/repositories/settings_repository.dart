import 'package:doon_walkers/features/settings/domain/entities/app_settings.dart';

/// Abstract interface for reading community settings.
///
/// Write access is intentionally not part of this interface — settings
/// are admin-write-only at the database level (RLS, 0002_role_policies.sql)
/// and the admin editor UI is out of scope until Phase 9.
abstract class SettingsRepository {
  /// Streams the full settings table as an [AppSettings] snapshot,
  /// re-emitting whenever any row changes (e.g. an admin edit via the
  /// Supabase dashboard) so callers stay live without a manual refetch.
  Stream<AppSettings> watchSettings();
}
