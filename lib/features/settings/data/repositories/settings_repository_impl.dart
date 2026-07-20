import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/settings/domain/entities/app_settings.dart';
import 'package:doon_walkers/features/settings/domain/repositories/settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Riverpod provider exposing the implementation of [SettingsRepository].
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepositoryImpl(ref.watch(supabaseClientProvider)),
  name: 'settingsRepositoryProvider',
);

/// Supabase implementation of [SettingsRepository].
class SettingsRepositoryImpl implements SettingsRepository {
  final SupabaseClient _supabase;

  const SettingsRepositoryImpl(this._supabase);

  @override
  Future<AppSettings> fetchSettings() async {
    final rows = await _supabase.from(AppConstants.tableSettings).select();
    return AppSettings.fromRows(rows);
  }
}
