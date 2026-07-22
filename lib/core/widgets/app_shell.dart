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
/// Primary destinations (bottom nav):
///   - Everyone: Home, Treks, Profile (3 tabs — identical for guest,
///     regular user, and admin).
///   - Admin additionally gets a 4th tab: Trek Registrations.
///
/// Secondary destination (Navigation Drawer):
///   Admin Dashboard — only rendered at all when the signed-in user is
///   an admin (see [isAdminProvider] watch below); a guest or regular
///   member sees an empty drawer body (just branding/version), not a
///   non-functional item they can tap.
///
/// The selected tab is derived from the current [GoRouterState] location
/// so that deep-links automatically highlight the correct tab.
///
/// History: Gallery used to be a standalone tab for everyone; it was
/// removed entirely (gallery MANAGEMENT still lives inline on each Trek
/// Detail page's TrekGallerySection, untouched) in favour of giving
/// admin a genuinely useful 4th tab instead. Because tab COUNT is now
/// role-dependent for the first time — previously every role saw the
/// exact same fixed tab set, with Admin as the only non-tabbed,
/// drawer-only branch — [_AppShellState] must handle a role flipping
/// while the app is open, in both directions, without the bottom nav's
/// `selectedIndex` ever pointing past the end of a shrunk destinations
/// list. See [_AppShellState.build] for how.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  /// Provided by GoRouter's [StatefulShellRoute].
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
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

// Order here MUST match the branch order in app_router.dart (branches
// 0-3) — NavigationBar's selectedIndex is a raw branch index, and
// _AppShellState's clamp below assumes every branch index less than
// the CURRENT role's destinations.length is one of these tabs, in this
// order.
const _baseDestinations = [
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
    label: 'Profile',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    route: AppConstants.routeProfile,
  ),
];

const _adminDestination = _NavDestination(
  label: 'Registrations',
  icon: Icons.groups_outlined,
  selectedIcon: Icons.groups,
  route: AppConstants.routeAdminTrekRegistrations,
);

/// Resolves what `NavigationBar.selectedIndex` should show, given:
///   - [currentIndex]: the router's actual branch index right now (0-4,
///     regardless of role — every branch always exists in the route
///     tree; see app_router.dart's branch layout doc).
///   - [destinationsLength]: how many bottom tabs THIS role currently
///     gets (3 for guest/member, 4 for admin).
///   - [lastPrimaryIndex]: the last tab index that WAS valid to show
///     selected, from a previous call.
///
/// Returns `(selectedIndex, nextLastPrimaryIndex)` — the second value is
/// what the caller should store and pass back in as [lastPrimaryIndex]
/// on the next call, mirroring `_AppShellState._lastPrimaryIndex`.
///
/// Pulled out of [_AppShellState] as a pure function so the exact bug
/// class this guards against — an out-of-range `selectedIndex` reaching
/// `NavigationBar` and tripping its assertion, the crash history this
/// project has already hit once — has direct unit coverage instead of
/// only the manual device trace. Covers both directions: [currentIndex]
/// pointing at the always-drawer-only Admin Dashboard branch (4), AND
/// pointing at the admin-only Trek Registrations branch (3) right after
/// a demotion shrinks [destinationsLength] out from under it.
@visibleForTesting
(int selectedIndex, int nextLastPrimaryIndex) resolveSelectedTabIndex({
  required int currentIndex,
  required int destinationsLength,
  required int lastPrimaryIndex,
}) {
  if (currentIndex < destinationsLength) {
    return (currentIndex, currentIndex);
  }
  if (lastPrimaryIndex < destinationsLength) {
    return (lastPrimaryIndex, lastPrimaryIndex);
  }
  // Even the fallback no longer exists for this role (e.g. it was 3 —
  // Trek Registrations — from before a demotion). Home (index 0) always
  // exists for every role, so reset to it rather than carry a
  // permanently-stale lastPrimaryIndex forward.
  return (0, 0);
}

// Branch index of Trek Registrations — must match its position in
// app_router.dart's branches list (0 Home, 1 Treks, 2 Profile, 3 Trek
// Registrations, 4 Admin Dashboard).
const _trekRegistrationsBranchIndex = 3;

class _AppShellState extends ConsumerState<AppShell> {
  // Tracks whichever primary tab was last actually valid to show
  // selected — see [resolveSelectedTabIndex] for the full reasoning and
  // the two cases it now has to handle (the always-drawer-only Admin
  // Dashboard branch, and the admin-only Trek Registrations branch
  // right after a demotion).
  int _lastPrimaryIndex = 0;

  void _onTabSelected(BuildContext context, int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    // GoRouter's own `redirect` (app_router.dart) is the primary guard
    // against a demoted admin staying on an admin-only route, and it's
    // enough for most cases (verified live: it correctly bounces a
    // demoted user off /admin itself). But it re-evaluates against the
    // router's declarative top-level location, and Trek Registrations'
    // detail routes are reached via push() *within* this branch's own
    // Navigator — verified live that a demotion while several pushes
    // deep on this branch does NOT reliably re-trigger `redirect` on its
    // own. Rather than depend on that timing, this listener is a second,
    // precisely-scoped line of defense: the ONE transition that can
    // strand a viewer on now-forbidden content is admin-with-role
    // becoming non-admin while sitting on branch 3 specifically (not
    // branch 4, the Admin Dashboard — reaching that one via the drawer
    // is normal for an admin and must NOT trigger this). When that exact
    // transition happens, actively navigate to Home — a plain context.go
    // call, which (unlike push) always resets to a clean top-level
    // match, so it works regardless of how many pages were pushed within
    // the branch.
    ref.listen<bool>(isAdminProvider, (previous, next) {
      if (previous == true &&
          next == false &&
          widget.navigationShell.currentIndex == _trekRegistrationsBranchIndex) {
        context.go(AppConstants.routeHome);
      }
    });

    final isAdmin = ref.watch(isAdminProvider);
    final destinations = isAdmin ? [..._baseDestinations, _adminDestination] : _baseDestinations;

    final (selectedIndex, nextLastPrimaryIndex) = resolveSelectedTabIndex(
      currentIndex: widget.navigationShell.currentIndex,
      destinationsLength: destinations.length,
      lastPrimaryIndex: _lastPrimaryIndex,
    );
    _lastPrimaryIndex = nextLastPrimaryIndex;

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
          // The Admin Dashboard is the only destination ever present,
          // so any selection here — index is always 0 — means it.
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
      ),

      // ── Primary navigation: Material 3 NavigationBar ─────────────
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) => _onTabSelected(context, i),
        destinations: destinations
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
