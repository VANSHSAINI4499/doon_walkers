import 'dart:async';

import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Riverpod provider exposing the implementation of [AuthRepository].
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(supabaseClientProvider)),
  name: 'authRepositoryProvider',
);

/// How long to wait on a Supabase auth call before giving up. Without this,
/// a stalled network request (as opposed to one that throws) leaves
/// [AsyncValue.guard] pending forever and the caller's loading state spins
/// indefinitely with no error surfaced.
const _authCallTimeout = Duration(seconds: 15);

/// How many times to retry a call that failed with
/// [AuthRetryableFetchException] (Supabase's own SDK already classifies
/// this as transient — e.g. a DNS blip or a dropped connection mid-request
/// — as opposed to a real auth failure like a wrong password, which is
/// never retried here). 3 attempts total: the original try plus 2 retries.
const _maxAttempts = 3;

/// Linear backoff between retries — attempt 2 waits this long, attempt 3
/// waits double. Short on purpose: this is masking a blip, not waiting out
/// a real outage, and every attempt still has its own [_authCallTimeout].
const _retryDelay = Duration(milliseconds: 600);

/// Supabase implementation of [AuthRepository].
class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _supabase;

  const AuthRepositoryImpl(this._supabase);

  @override
  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _withRetry(
        () => _supabase.auth
            .signInWithPassword(email: email.trim(), password: password)
            .timeout(_authCallTimeout),
      );
    } on TimeoutException {
      throw Exception(_timeoutMessage);
    }
  }

  @override
  Future<SignUpResult> signUpWithEmailPassword({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final AuthResponse response;
    try {
      response = await _withRetry(
        () => _supabase.auth
            .signUp(
              email: email.trim(),
              password: password,
              data: {
                'full_name': fullName.trim(),
              },
            )
            .timeout(_authCallTimeout),
      );
    } on TimeoutException {
      throw Exception(_timeoutMessage);
    }
    return response.session != null
        ? SignUpResult.sessionCreated
        : SignUpResult.confirmationPending;
  }

  @override
  Future<void> signOut() async {
    try {
      await _withRetry(() => _supabase.auth.signOut().timeout(_authCallTimeout));
    } on TimeoutException {
      throw Exception(_timeoutMessage);
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _withRetry(
        () => _supabase.auth.resetPasswordForEmail(email.trim()).timeout(_authCallTimeout),
      );
    } on TimeoutException {
      throw Exception(_timeoutMessage);
    }
  }

  /// Retries [action] when it fails with [AuthRetryableFetchException] —
  /// see [_maxAttempts]'s doc for why only that specific exception is
  /// worth retrying here.
  Future<T> _withRetry<T>(Future<T> Function() action) async {
    var attempt = 1;
    while (true) {
      try {
        return await action();
      } on AuthRetryableFetchException {
        if (attempt >= _maxAttempts) rethrow;
        await Future.delayed(_retryDelay * attempt);
        attempt++;
      }
    }
  }

  static const _timeoutMessage =
      'Request timed out. Please check your connection and try again.';
}
