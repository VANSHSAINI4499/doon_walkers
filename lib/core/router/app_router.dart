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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A [ChangeNotifier] that notifies listeners whenever the provided [stream] emits an event.
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// DoonWalkers application router.
///
/// Uses [GoRouter] with a [StatefulShellRoute] so that:
///   - The 5 primary tabs each maintain their own navigation stack.
///   - The [AppShell] (bottom nav + drawer) persists across route transitions.
///   - Profile and Admin routes live inside the shell (drawer keeps visible)
///     but as standalone branches not surfaced in the bottom nav.
///   - Auth routes (/sign-in, /sign-up, /forgot-password) are top-level outside
///     the shell so bottom navigation bars are suppressed.
final GoRouter appRouter = GoRouter(
  initialLocation: AppConstants.routeHome,
  debugLogDiagnostics: true, // disable in release builds
  refreshListenable: GoRouterRefreshStream(Supabase.instance.client.auth.onAuthStateChange),
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
      try {
        final container = ProviderScope.containerOf(context);
        final isAdmin = container.read(isAdminProvider);
        if (!isAdmin) {
          // Non-admin registered user hitting /admin -> silently bounced to Home per AGENTS.md rules
          return AppConstants.routeHome;
        }
      } catch (_) {
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
