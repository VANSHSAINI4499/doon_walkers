import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Utility class providing guard methods for actions and routes.
class AuthGuard {
  const AuthGuard._();

  /// Checks if the user is authenticated before performing [onAuthenticated].
  ///
  /// If the user is a guest (not signed in), they are immediately redirected to
  /// `/sign-in` with a `redirectTo` query parameter set to [returnPath] (or the
  /// current route URI if not specified).
  ///
  /// Example usage:
  /// ```dart
  /// AuthGuard.requireAuth(
  ///   context,
  ///   onAuthenticated: () => _openRegistrationModal(),
  /// );
  /// ```
  static void requireAuth(
    BuildContext context, {
    required VoidCallback onAuthenticated,
    String? returnPath,
  }) {
    final supabase = Supabase.instance.client;
    final sessionUser = supabase.auth.currentUser;

    if (sessionUser != null) {
      onAuthenticated();
      return;
    }

    // Determine return destination
    final targetPath = returnPath ?? GoRouterState.of(context).uri.toString();
    final signInUrl = Uri(
      path: AppConstants.routeSignIn,
      queryParameters: {'redirectTo': targetPath},
    ).toString();

    context.push(signInUrl);
  }

  /// Checks phone verification (in addition to sign-in) before performing
  /// [onVerified] — the gate trek registration, comment posting, and
  /// merch "Buy Now" all use (Version 2, Phase Auth Upgrade).
  ///
  /// Deliberately built ON TOP of [requireAuth] rather than duplicating
  /// its redirect, so a guest still gets exactly the sign-in
  /// bounce-and-return [requireAuth] already provides — this only adds a
  /// second check, once signed in, for [isPhoneVerifiedProvider]. If
  /// that's false, it pushes to the phone verification screen with the
  /// same `redirectTo` convention, so the user lands back on this exact
  /// page (not the original action re-firing automatically — same
  /// "tap again after bouncing back" shape [requireAuth] already has).
  static void requirePhoneVerified(
    BuildContext context, {
    required VoidCallback onVerified,
    String? returnPath,
  }) {
    requireAuth(
      context,
      returnPath: returnPath,
      onAuthenticated: () {
        if (_isPhoneVerified(context)) {
          onVerified();
          return;
        }

        final targetPath = returnPath ?? GoRouterState.of(context).uri.toString();
        final verifyUrl = Uri(
          path: AppConstants.routePhoneVerification,
          queryParameters: {'redirectTo': targetPath},
        ).toString();
        context.push(verifyUrl);
      },
    );
  }

  static bool _isPhoneVerified(BuildContext context) {
    try {
      final container = ProviderScope.containerOf(context);
      return container.read(isPhoneVerifiedProvider);
    } catch (_) {
      return false;
    }
  }

  /// Checks if the active user is an administrator via Riverpod [ProviderContainer].
  ///
  /// Useful for conditional UI rendering inside action buttons where `ref` might
  /// not be immediately available in callbacks.
  static bool isAdmin(BuildContext context) {
    try {
      final container = ProviderScope.containerOf(context);
      return container.read(isAdminProvider);
    } catch (_) {
      return false;
    }
  }
}
