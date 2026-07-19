import 'dart:async';
import 'package:doon_walkers/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Riverpod AsyncNotifier managing the state of auth actions (loading, error, success).
final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
  name: 'authControllerProvider',
);

class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    // Initial state is idle (null inside AsyncData)
  }

  /// Signs in with [email] and [password].
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInWithEmailPassword(
            email: email,
            password: password,
          ),
    );
  }

  /// Signs up a new user with [fullName], [email], and [password].
  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signUpWithEmailPassword(
            email: email,
            password: password,
            fullName: fullName,
          ),
    );
  }

  /// Signs out the current user session.
  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signOut(),
    );
  }

  /// Sends a password recovery link to [email].
  Future<void> sendPasswordResetEmail(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).sendPasswordResetEmail(email),
    );
  }
}
