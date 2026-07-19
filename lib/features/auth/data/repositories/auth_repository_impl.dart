import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Riverpod provider exposing the implementation of [AuthRepository].
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(supabaseClientProvider)),
  name: 'authRepositoryProvider',
);

/// Supabase implementation of [AuthRepository].
class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _supabase;

  const AuthRepositoryImpl(this._supabase);

  @override
  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> signUpWithEmailPassword({
    required String email,
    required String password,
    required String fullName,
  }) async {
    await _supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName.trim(),
      },
    );
  }

  @override
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _supabase.auth.resetPasswordForEmail(email.trim());
  }
}
