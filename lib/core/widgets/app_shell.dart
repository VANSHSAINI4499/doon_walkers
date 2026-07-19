import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/theme/app_colors.dart';
import 'package:doon_walkers/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Persistent navigation shell for the app.
///
/// Wraps GoRouter's [ShellRoute] so the [NavigationBar] and
/// [NavigationDrawer] persist across route transitions.
///
/// Primary destinations (bottom nav — 5 tabs):
///   Home, Treks, Gallery, Upcoming, About
///
/// Secondary destinations (Navigation Drawer):
///   Profile, Admin
///
/// The selected tab is derived from the current [GoRouterState] location
/// so that deep-links automatically highlight the correct tab.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  /// Provided by GoRouter's [StatefulShellRoute].
  final StatefulNavigationShell navigationShell;

  // ── Primary tab destinations ────────────────────────────────────
  static const List<_NavDestination> _primaryDestinations = [
    _NavDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      route: AppConstants.routeHome,
    ),
    _NavDestination(
      label: 'Treks',
      icon: Icons.terrain_outlined,
      selectedIcon: Icons.terrain,
      route: AppConstants.routeTrekLibrary,
    ),
    _NavDestination(
      label: 'Gallery',
      icon: Icons.photo_library_outlined,
      selectedIcon: Icons.photo_library,
      route: AppConstants.routeGallery,
    ),
    _NavDestination(
      label: 'Upcoming',
      icon: Icons.event_outlined,
      selectedIcon: Icons.event,
      route: AppConstants.routeUpcomingTreks,
    ),
    _NavDestination(
      label: 'About',
      icon: Icons.info_outline,
      selectedIcon: Icons.info,
      route: AppConstants.routeAbout,
    ),
  ];

  void _onTabSelected(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppConstants.appName,
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.onPrimary),
        ),
        actions: [
          // Opens the secondary NavigationDrawer
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu, color: AppColors.onPrimary),
              tooltip: 'More',
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
        ],
      ),

      // ── Secondary navigation: Material 3 NavigationDrawer ────────
      endDrawer: NavigationDrawer(
        onDestinationSelected: (index) {
          Navigator.of(context).pop(); // close drawer
          if (index == 0) {
            context.go(AppConstants.routeProfile);
          } else if (index == 1) {
            context.go(AppConstants.routeAdmin);
          }
        },
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 16, 10),
            child: Text(
              AppConstants.appName,
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
          const Divider(indent: 28, endIndent: 28),
          const NavigationDrawerDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: Text('Profile'),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings),
            label: Text('Admin'),
          ),
          const Divider(indent: 28, endIndent: 28),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 8, 16, 0),
            child: Text(
              'v${AppConstants.appVersion}',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textDisabled,
              ),
            ),
          ),
        ],
      ),

      // ── Primary navigation: Material 3 NavigationBar ─────────────
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => _onTabSelected(context, i),
        destinations: _primaryDestinations
            .map(
              (d) => NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
            )
            .toList(),
      ),

      // ── Shell body ───────────────────────────────────────────────
      body: navigationShell,
    );
  }
}

/// Immutable descriptor for a primary nav tab destination.
class _NavDestination {
  const _NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
}
