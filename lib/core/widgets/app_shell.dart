import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/core/theme/app_colors.dart';
import 'package:doon_walkers/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Persistent navigation shell for the app.
///
/// Wraps GoRouter's [ShellRoute] so the [NavigationBar] and
/// [NavigationDrawer] persist across route transitions.
///
/// Primary destinations (bottom nav — 4 tabs):
///   Home, Treks, Gallery, Profile
///
/// Secondary destination (Navigation Drawer):
///   Admin — only rendered at all when the signed-in user is an admin
///   (see [isAdminProvider] watch below); a guest or regular member sees
///   an empty drawer body (just branding/version), not a non-functional
///   item they can tap.
///
/// The selected tab is derived from the current [GoRouterState] location
/// so that deep-links automatically highlight the correct tab.
///
/// History: Profile used to be drawer-only, alongside Admin, giving 2
/// non-tabbed branches out of 7 total. Part B of the nav restructure
/// moved Profile into the tab bar (replacing About's old slot), leaving
/// Admin as the ONLY non-tabbed branch out of 5 total. See
/// [_AppShellState._lastPrimaryIndex] for why that branch-count change
/// needed no change to the clamping logic itself.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  /// Provided by GoRouter's [StatefulShellRoute].
  final StatefulNavigationShell navigationShell;

  // ── Primary tab destinations ────────────────────────────────────
  // Order here MUST match the branch order in app_router.dart (branches
  // 0-3) — NavigationBar's selectedIndex is a raw branch index, and
  // _lastPrimaryIndex's clamp below assumes every branch index less than
  // this list's length is one of these tabs, in this order.
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
      label: 'Profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      route: AppConstants.routeProfile,
    ),
  ];

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Branch 4 (Admin) is the one remaining drawer-only branch — it has no
  // corresponding bottom nav destination, so `navigationShell.currentIndex`
  // can't be fed to NavigationBar directly when it's active — it would
  // exceed destinations.length and trip its selectedIndex assertion.
  // Instead we track whichever of the primary tabs was last actually
  // active, and keep showing that as "selected" while Admin is active.
  //
  // This clamp is branch-COUNT-agnostic by construction — it compares
  // against `_primaryDestinations.length`, not a hardcoded number, so
  // going from 7 branches/2 non-tabbed (Profile+Admin) to 5 branches/1
  // non-tabbed (Admin only) needed no change here, only to the
  // destinations list above and the router's branch order matching it.
  int _lastPrimaryIndex = 0;

  void _onTabSelected(BuildContext context, int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;
    if (currentIndex < AppShell._primaryDestinations.length) {
      _lastPrimaryIndex = currentIndex;
    }

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
      endDrawer: Consumer(
        builder: (context, ref, _) {
          // Profile moved into the bottom tab bar in Part B, so Admin is
          // the drawer's only possible destination now — and it's
          // rendered at all only for an admin. A guest/regular member
          // opening the drawer sees just branding/version, not a
          // non-functional item they could tap and have nothing happen.
          final isAdmin = ref.watch(isAdminProvider);

          return NavigationDrawer(
            onDestinationSelected: (index) {
              Navigator.of(context).pop(); // close drawer
              // Admin is the only destination ever present, so any
              // selection here — index is always 0 — means Admin.
              if (isAdmin) context.go(AppConstants.routeAdmin);
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
              if (isAdmin)
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
          );
        },
      ),

      // ── Primary navigation: Material 3 NavigationBar ─────────────
      bottomNavigationBar: NavigationBar(
        selectedIndex: _lastPrimaryIndex,
        onDestinationSelected: (i) => _onTabSelected(context, i),
        destinations: AppShell._primaryDestinations
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
      body: widget.navigationShell,
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
