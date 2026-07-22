import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/notifications/domain/repositories/device_token_repository.dart';
import 'package:flutter/foundation.dart';
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
    final userId = _currentUserId;
    debugPrint('[Push] upsertToken: user_id=$userId, fcm_token=$fcmToken');
    try {
      await _supabase.from(AppConstants.tableDeviceTokens).upsert(
        {
          'user_id': userId,
          'fcm_token': fcmToken,
          'platform': 'android',
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'fcm_token',
      );
      debugPrint('[Push] upsertToken: Supabase upsert call returned without error');
    } on PostgrestException catch (e) {
      debugPrint('[Push] upsertToken: PostgrestException code=${e.code}, '
          'message=${e.message}, details=${e.details}, hint=${e.hint}');
      rethrow;
    } catch (e) {
      debugPrint('[Push] upsertToken: unexpected error: $e');
      rethrow;
    }
  }

  @override
  Future<void> removeToken(String fcmToken) async {
    debugPrint('[Push] removeToken: fcm_token=$fcmToken');
    try {
      await _supabase.from(AppConstants.tableDeviceTokens).delete().eq('fcm_token', fcmToken);
      debugPrint('[Push] removeToken: Supabase delete call returned without error');
    } on PostgrestException catch (e) {
      debugPrint('[Push] removeToken: PostgrestException code=${e.code}, '
          'message=${e.message}, details=${e.details}, hint=${e.hint}');
      rethrow;
    } catch (e) {
      debugPrint('[Push] removeToken: unexpected error: $e');
      rethrow;
    }
  }
}
