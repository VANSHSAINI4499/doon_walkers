import 'dart:async';
import 'package:doon_walkers/core/services/push_notification_service.dart';
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

  /// Signs in (or signs up, on first use) via the native Google account
  /// picker. See [AuthRepository.signInWithGoogle] for the cancel/error
  /// distinction — a dismissed picker leaves [state] as [AsyncData], not
  /// [AsyncError].
  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInWithGoogle(),
    );
  }

  /// Signs out the current user session.
  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // MUST run before the actual sign-out, not after — removing this
      // device's token row needs auth.uid() to still resolve to this
      // user (device_tokens_delete_own's RLS check); once the session
      // is cleared there's no matching auth.uid() left to satisfy it.
      // Best-effort: a failure here shouldn't block the user from
      // actually signing out.
      try {
        await ref.read(pushNotificationServiceProvider).removeTokenForCurrentUser();
      } catch (_) {
        // Worst case: a stale token row lingers until the next device
        // that signs in on this phone reassigns it (upsert-by-token) or
        // FCM itself reports it invalid and the Edge Function prunes
        // it — not worth failing sign-out over.
      }
      await ref.read(authRepositoryProvider).signOut();
    });
  }

  /// Sends a password recovery link to [email].
  Future<void> sendPasswordResetEmail(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).sendPasswordResetEmail(email),
    );
  }
}
