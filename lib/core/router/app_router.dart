import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/widgets/app_shell.dart';
import 'package:doon_walkers/features/about/presentation/screens/about_screen.dart';
import 'package:doon_walkers/features/admin/presentation/screens/admin_screen.dart';
import 'package:doon_walkers/features/gallery/presentation/screens/gallery_screen.dart';
import 'package:doon_walkers/features/home/presentation/screens/home_screen.dart';
import 'package:doon_walkers/features/profile/presentation/screens/profile_screen.dart';
import 'package:doon_walkers/features/trek_library/presentation/screens/trek_library_screen.dart';
import 'package:doon_walkers/features/upcoming_treks/presentation/screens/upcoming_treks_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// DoonWalkers application router.
///
/// Uses [GoRouter] with a [StatefulShellRoute] so that:
///   - The 5 primary tabs each maintain their own navigation stack.
///   - The [AppShell] (bottom nav + drawer) persists across route transitions.
///   - Profile and Admin routes live inside the shell (drawer keeps visible)
///     but as standalone branches not surfaced in the bottom nav.
///
/// Routes:
///   /                 → HomeScreen
///   /trek-library     → TrekLibraryScreen
///   /gallery          → GalleryScreen
///   /upcoming-treks   → UpcomingTreksScreen
///   /about            → AboutScreen
///   /profile          → ProfileScreen      (via drawer)
///   /admin            → AdminScreen        (via drawer)
final GoRouter appRouter = GoRouter(
  initialLocation: AppConstants.routeHome,
  debugLogDiagnostics: true, // disable in release builds
  routes: [
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

  // Redirect hook — Phase 2 will add auth-based redirects here.
  redirect: (context, state) => null,

  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Page not found: ${state.uri}'),
    ),
  ),
);
