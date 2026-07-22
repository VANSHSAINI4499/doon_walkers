import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/notifications/domain/repositories/device_token_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Riverpod provider exposing the implementation of [DeviceTokenRepository].
final deviceTokenRepositoryProvider = Provider<DeviceTokenRepository>(
  (ref) => DeviceTokenRepositoryImpl(ref.watch(supabaseClientProvider)),
  name: 'deviceTokenRepositoryProvider',
);

/// Supabase implementation of [DeviceTokenRepository].
class DeviceTokenRepositoryImpl implements DeviceTokenRepository {
  final SupabaseClient _supabase;

  const DeviceTokenRepositoryImpl(this._supabase);

  String get _currentUserId {
    final id = _supabase.auth.currentUser?.id;
    if (id == null) {
      throw Exception('You need to be signed in to do that.');
    }
    return id;
  }

  @override
  Future<void> upsertToken(String fcmToken) async {
    await _supabase.from(AppConstants.tableDeviceTokens).upsert(
      {
        'user_id': _currentUserId,
        'fcm_token': fcmToken,
        'platform': 'android',
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'fcm_token',
    );
  }

  @override
  Future<void> removeToken(String fcmToken) async {
    await _supabase.from(AppConstants.tableDeviceTokens).delete().eq('fcm_token', fcmToken);
  }
}
