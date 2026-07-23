import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/auth/domain/repositories/user_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Riverpod provider exposing the implementation of [UserRepository].
final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepositoryImpl(ref.watch(supabaseClientProvider)),
  name: 'userRepositoryProvider',
);

/// Supabase implementation of [UserRepository].
class UserRepositoryImpl implements UserRepository {
  final SupabaseClient _supabase;

  const UserRepositoryImpl(this._supabase);

  @override
  Future<void> updateShowOnLeaderboard(bool value) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('updateShowOnLeaderboard called with no signed-in user');
    }
    await _supabase
        .from(AppConstants.tableUsers)
        .update({'show_on_leaderboard': value}).eq('id', userId);
  }
}
