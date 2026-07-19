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
