import 'dart:async';
import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/core/widgets/app_shell.dart';
import 'package:doon_walkers/features/about/presentation/screens/about_screen.dart';
import 'package:doon_walkers/features/admin/presentation/screens/admin_screen.dart';
import 'package:doon_walkers/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:doon_walkers/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:doon_walkers/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:doon_walkers/features/gallery/presentation/screens/gallery_screen.dart';
import 'package:doon_walkers/features/home/presentation/screens/home_screen.dart';
import 'package:doon_walkers/features/profile/presentation/screens/profile_screen.dart';
import 'package:doon_walkers/features/trek_library/presentation/screens/trek_library_screen.dart';
import 'package:doon_walkers/features/upcoming_treks/presentation/screens/upcoming_treks_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A [ChangeNotifier] that drives GoRouter's [refreshListenable].
///
/// Notifies on two independent signals:
///   1. Supabase's raw `onAuthStateChange` — sign-in, sign-out, token refresh.
///   2. [currentUserProvider] — the `public.users` row for the signed-in user.
///      This is what lets a *late-arriving* role (the row loading a moment
///      after sign-in) re-trigger the redirect logic, instead of only
///      re-evaluating on the initial auth event. Without this, an admin who
///      hits `/admin` before their row has loaded once would get redirected
///      to Home by the loading-guard in [redirect] and then never get
///      re-checked, since raw auth events don't fire again just because a
///      Riverpod stream resolved.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange
        .asBroadcastStream()
        .listen((_) => notifyListeners());

    ref.listen(currentUserProvider, (previous, next) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}

/// Exposes the [GoRouter] instance as a Riverpod provider (rather than a
/// bare top-level field) so its `redirect` logic can [Ref.read] Riverpod
/// state directly and its refresh listenable can [Ref.listen] to it — see
/// [_RouterRefreshNotifier].
final routerProvider = Provider<GoRouter>(
  (ref) {
    final refreshNotifier = _RouterRefreshNotifier(ref);
    ref.onDispose(refreshNotifier.dispose);

    return _buildRouter(ref, refreshNotifier);
  },
  name: 'routerProvider',
);

/// DoonWalkers application router.
///
/// Uses [GoRouter] with a [StatefulShellRoute] so that:
///   - The 5 primary tabs each maintain their own navigation stack.
///   - The [AppShell] (bottom nav + drawer) persists across route transitions.
///   - Profile and Admin routes live inside the shell (drawer keeps visible)
///     but as standalone branches not surfaced in the bottom nav.
///   - Auth routes (/sign-in, /sign-up, /forgot-password) are top-level outside
///     the shell so bottom navigation bars are suppressed.
GoRouter _buildRouter(Ref ref, _RouterRefreshNotifier refreshNotifier) => GoRouter(
  initialLocation: AppConstants.routeHome,
  debugLogDiagnostics: kDebugMode,
  refreshListenable: refreshNotifier,
  routes: [
    // Top-Level Auth Routes (Outside AppShell)
    GoRoute(
      path: AppConstants.routeSignIn,
      name: 'sign-in',
      builder: (context, state) => SignInScreen(
        redirectTo: state.uri.queryParameters['redirectTo'],
      ),
    ),
    GoRoute(
      path: AppConstants.routeSignUp,
      name: 'sign-up',
      builder: (context, state) => SignUpScreen(
        redirectTo: state.uri.queryParameters['redirectTo'],
      ),
    ),
    GoRoute(
      path: AppConstants.routeForgotPassword,
      name: 'forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),

    // StatefulShellRoute for App Navigation Tabs & Drawer Screens
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        // Branch 0 — Home
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppConstants.routeHome,
              name: 'home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),

        // Branch 1 — Trek Library
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppConstants.routeTrekLibrary,
              name: 'trek-library',
              builder: (context, state) => const TrekLibraryScreen(),
            ),
          ],
        ),

        // Branch 2 — Gallery
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppConstants.routeGallery,
              name: 'gallery',
              builder: (context, state) => const GalleryScreen(),
            ),
          ],
        ),

        // Branch 3 — Upcoming Treks
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppConstants.routeUpcomingTreks,
              name: 'upcoming-treks',
              builder: (context, state) => const UpcomingTreksScreen(),
            ),
          ],
        ),

        // Branch 4 — About
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppConstants.routeAbout,
              name: 'about',
              builder: (context, state) => const AboutScreen(),
            ),
          ],
        ),

        // Branch 5 — Profile (secondary, drawer)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppConstants.routeProfile,
              name: 'profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),

        // Branch 6 — Admin (secondary, drawer)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppConstants.routeAdmin,
              name: 'admin',
              builder: (context, state) => const AdminScreen(),
            ),
          ],
        ),
      ],
    ),
  ],

  // Auth Guard & Redirect Hook
  redirect: (context, state) {
    final supabase = Supabase.instance.client;
    final sessionUser = supabase.auth.currentUser;
    final location = state.uri.path;

    // Check if target is an auth screen
    final isAuthScreen = location == AppConstants.routeSignIn ||
        location == AppConstants.routeSignUp ||
        location == AppConstants.routeForgotPassword;

    // 1. If user is signed in and trying to visit an auth screen, redirect to destination or home
    if (sessionUser != null && isAuthScreen) {
      return state.uri.queryParameters['redirectTo'] ?? AppConstants.routeHome;
    }

    // 2. If user is guest and trying to visit protected routes (/profile or /admin), redirect to Sign In
    final isProtectedRoute = location == AppConstants.routeProfile ||
        location == AppConstants.routeAdmin;
    if (sessionUser == null && isProtectedRoute) {
      return '${AppConstants.routeSignIn}?redirectTo=${Uri.encodeComponent(state.uri.toString())}';
    }

    // 3. If user is signed in and trying to visit /admin, verify admin role
    if (sessionUser != null && location == AppConstants.routeAdmin) {
      final userAsync = ref.read(currentUserProvider);

      // The public.users row hasn't resolved yet (e.g. immediately after
      // sign-in) — don't gate on isAdminProvider while it's unknown, that
      // silently and permanently bounces real admins to Home. Let the
      // navigation through for now; _RouterRefreshNotifier re-runs this
      // check the moment currentUserProvider actually resolves.
      if (userAsync.isLoading && !userAsync.hasValue) {
        return null;
      }

      final isAdmin = ref.read(isAdminProvider);
      if (!isAdmin) {
        // Non-admin registered user hitting /admin -> silently bounced to Home per AGENTS.md rules
        return AppConstants.routeHome;
      }
    }

    return null; // no redirect
  },

  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Page not found: ${state.uri}'),
    ),
  ),
);
