import 'dart:async';
import 'package:doon_walkers/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:doon_walkers/features/auth/domain/repositories/auth_repository.dart';
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
  ///
  /// Returns the [SignUpResult] on success so the caller can branch UI
  /// (e.g. show a "check your email" state vs. relying on the router's
  /// auto-redirect). [state] stays `AsyncValue<void>` — shared with the
  /// other auth actions — so the result is only available via this
  /// method's return value, not through `state.value`. Returns `null`
  /// if sign-up failed; the error itself is exposed via [state].
  Future<SignUpResult?> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    SignUpResult? result;
    state = await AsyncValue.guard(() async {
      result = await ref.read(authRepositoryProvider).signUpWithEmailPassword(
            email: email,
            password: password,
            fullName: fullName,
          );
    });
    return result;
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
