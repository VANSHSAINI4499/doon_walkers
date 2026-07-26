import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/activity/presentation/providers/activity_providers.dart';
import 'package:doon_walkers/features/notifications/presentation/providers/notification_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Persistent navigation shell — bottom nav, app bar chrome and drawer,
/// wrapped around GoRouter's [StatefulShellRoute] so all three persist
/// across route transitions.
///
/// ## Navigation structure (Redesign 2.0, Phase 10)
///
/// **Five bottom tabs, identical for every role**: Home, Activity, Treks,
/// Challenges, Profile. Admin no longer gets an extra tab — Trek
/// Registrations moved to the drawer's admin section.
///
/// That single decision is what makes this file dramatically simpler than
/// its two predecessors. The tab set is now a `const` list. There is no
/// role-conditional destinations list, no tab count that changes under a
/// live role flip, and therefore none of the "selectedIndex points past
/// the end of a shrunk list" crash class that this shell has hit before.
/// [resolveSelectedTabIndex] survives, but only to handle the one
/// remaining case: branch 5 is admin-only standalone screens and is
/// *never* a tab, so a router index of 5 has no tab to highlight.
///
/// **Drawer**: Merchandise, About, Support, Settings, Contact — plus an
/// Admin section, rendered only for an admin, containing Registrations
/// (the relocated tab), Merchandise Inquiries and Send Notification.
///
/// The selected tab is derived from the current branch index, so
/// deep-links highlight the correct tab automatically.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  /// Provided by GoRouter's [StatefulShellRoute].
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

/// Immutable descriptor for a primary nav tab destination.
///
/// A single [icon] rather than an icon/selectedIcon pair — Material
/// Symbols' filled-vs-hollow distinction is a font axis, not a different
/// glyph (see [AppIcon]'s doc), so selection is communicated by
/// [FloatingNavBar]'s own colour and indicator treatment instead of
/// swapping glyphs.
class _NavDestination {
  const _NavDestination({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;
}

/// The bottom tabs — **every role sees exactly these, in this order**.
///
/// Order here MUST match branches 0-4 in app_router.dart, because
/// `goBranch(index)` takes a raw branch index. Branch 5 (admin-only
/// standalone screens) intentionally has no entry: it is not a tab.
const _destinations = [
  _NavDestination(
    label: 'Home',
    icon: AppIcons.home,
    route: AppConstants.routeHome,
  ),
  _NavDestination(
    label: 'Activity',
    icon: AppIcons.steps,
    route: AppConstants.routeActivity,
  ),
  _NavDestination(
    label: 'Treks',
    icon: AppIcons.treks,
    route: AppConstants.routeTrekLibrary,
  ),
  _NavDestination(
    label: 'Community',
    icon: AppIcons.group,
    route: AppConstants.routeCommunity,
  ),
  _NavDestination(
    label: 'Profile',
    icon: AppIcons.profile,
    route: AppConstants.routeProfile,
  ),
];

/// How many branches are tabs. Branches `0 .. _tabCount-1` are the bottom
/// nav; anything at or above it is a non-tab branch.
///
/// A literal rather than `_destinations.length` because it is a default
/// parameter value on [resolveSelectedTabIndex] and therefore has to be a
/// compile-time constant, which a list's `.length` is not. [_AppShellState.build]
/// asserts the two agree, so they cannot drift apart unnoticed.
const int _tabCount = 5;

/// Resolves what the bottom nav's `selectedIndex` should show, given:
///   - [currentIndex]: the router's actual branch index right now (0-5).
///   - [lastPrimaryIndex]: the last index that WAS a real tab, from a
///     previous call.
///
/// Returns `(selectedIndex, nextLastPrimaryIndex)`; the caller stores the
/// second value and passes it back next time, mirroring
/// `_AppShellState._lastPrimaryIndex`.
///
/// ## What this guards, and why it is now purely defensive
///
/// This shell's crash history is about an out-of-range `selectedIndex`
/// reaching the nav bar and tripping its assertion. Two things could
/// cause it before:
///
///  1. The router sitting on a branch that is not a tab at all.
///  2. The tab list *shrinking* under the current selection, when an
///     admin was demoted while on their extra tab.
///
/// **Both are now structurally impossible.** Case 2 went away when every
/// role got the same five tabs, making [_tabCount] a compile-time
/// constant that never changes at runtime. Case 1 went away when the
/// admin-only screens moved out of the shell to top-level routes, which
/// left every remaining branch a tab.
///
/// This function is therefore expected never to take a fallback branch
/// today. It is kept — rather than deleted or collapsed to a one-liner —
/// because the invariant it encodes ("the nav bar is never handed an
/// index it cannot render") is the one this project has broken twice,
/// and the next person to add a non-tab branch should find a tested
/// guard already in place rather than rediscover the incident. Its tests
/// sweep indices no real router currently produces, on purpose.
@visibleForTesting
(int selectedIndex, int nextLastPrimaryIndex) resolveSelectedTabIndex({
  required int currentIndex,
  required int lastPrimaryIndex,
  int tabCount = _tabCount,
}) {
  if (currentIndex >= 0 && currentIndex < tabCount) {
    return (currentIndex, currentIndex);
  }
  if (lastPrimaryIndex >= 0 && lastPrimaryIndex < tabCount) {
    return (lastPrimaryIndex, lastPrimaryIndex);
  }
  // Home (index 0) exists for every role, always.
  return (0, 0);
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  // Whichever primary tab was last actually valid to show selected — see
  // [resolveSelectedTabIndex].
  int _lastPrimaryIndex = 0;

  @override
  void initState() {
    super.initState();
    // "Sync on app resume from background" (Version 2, Challenges Module
    // pivot) — AppShell is the natural place for this: it's mounted for
    // the app's entire lifetime once past sign-in/routing. "Sync on
    // launch" is a separate hook (activityLaunchSyncProvider, watched
    // from DoonWalkersApp) since that's an auth-state concern, not an
    // app-lifecycle one.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(activitySyncControllerProvider.notifier).sync();
    }
  }

  void _onTabSelected(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  void _openDrawerRoute(BuildContext context, String route) {
    Navigator.of(context).pop(); // close the drawer first
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    assert(
      _destinations.length == _tabCount,
      '_tabCount ($_tabCount) must match the number of bottom-nav '
      'destinations (${_destinations.length}). Adding or removing a tab '
      'means updating both, plus the branch order in app_router.dart.',
    );

    // No bespoke demotion listener here any more.
    //
    // There used to be one: when the admin-only screens lived inside this
    // shell as a branch, GoRouter's `redirect` could not be relied on to
    // fire for them, because they were reached by push() *within* a
    // branch's own Navigator rather than by a top-level location change.
    // Phase 10 moved every admin screen out to a top-level route (see
    // app_router.dart), so a demoted admin sitting on one is now bounced
    // by `redirect` itself — the same mechanism that already protects
    // every other /admin path — and the listener became unreachable code
    // pretending to be a safety net.
    //
    // `isAdminProvider` is still watched, but only to decide whether the
    // drawer shows its Admin section.
    final isAdmin = ref.watch(isAdminProvider);

    final (selectedIndex, nextLastPrimaryIndex) = resolveSelectedTabIndex(
      currentIndex: widget.navigationShell.currentIndex,
      lastPrimaryIndex: _lastPrimaryIndex,
    );
    _lastPrimaryIndex = nextLastPrimaryIndex;

    return Scaffold(
      appBar: AppBar(
        // Title, bell and menu all inherit their colour from the app bar
        // theme, which resolves per-theme — no hardcoded ink here, which
        // is what makes the chrome correct in light and dark alike.
        title: const Text(AppConstants.appName),
        actions: [
          // Notifications — always shown regardless of role or sign-in
          // state, same convention as the Profile tab: the router's own
          // guest-redirect guard is what protects /notifications, not
          // conditional visibility of the affordance that opens it.
          //
          // Phase 13 added the unread badge. The bell itself was already
          // correct from Phase 10 (theme-resolved ink, no hardcoded
          // colour), so this is additive rather than a restyle.
          const _NotificationBellAction(),
          Builder(
            builder: (ctx) => IconButton(
              icon: const AppIcon(AppIcons.menu),
              tooltip: 'More',
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
        ],
      ),

      endDrawer: _AppDrawer(
        isAdmin: isAdmin,
        onSelect: (route) => _openDrawerRoute(context, route),
      ),

      bottomNavigationBar: FloatingNavBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: _onTabSelected,
        destinations: _destinations
            .map((d) => FloatingNavBarDestination(icon: d.icon, label: d.label))
            .toList(),
      ),

      body: widget.navigationShell,
    );
  }
}

/// The app bar's bell, with an unread count badge.
///
/// The count comes from [unreadNotificationCountProvider], which compares
/// the visible notification list against this device's read state (see
/// `NotificationReadTracker` for why read state is device-local). It reads
/// 0 — and so renders no badge — while the list is loading and for a guest,
/// so the badge never flashes a number it then corrects.
///
/// Counts above 9 render as "9+": the badge is 16px, and the exact number
/// stops mattering well before it stops fitting.
class _NotificationBellAction extends ConsumerWidget {
  const _NotificationBellAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final unread = ref.watch(unreadNotificationCountProvider);

    return IconButton(
      tooltip: unread > 0 ? 'Notifications ($unread unread)' : 'Notifications',
      onPressed: () => context.push(AppConstants.routeNotifications),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const AppIcon(AppIcons.notifications),
          if (unread > 0)
            Positioned(
              // Nudged outside the glyph's box so the badge sits on the
              // bell's shoulder rather than covering it.
              top: -4,
              right: -5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(minWidth: 16),
                height: 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.primary,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  // A ring in the bar's own colour keeps the badge legible
                  // where it overlaps the dark bell glyph.
                  border: Border.all(color: palette.background, width: 1.5),
                ),
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: palette.onPrimary,
                    fontSize: 9,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The secondary navigation drawer.
///
/// A plain [Drawer] with hand-rolled rows rather than Material's
/// [NavigationDrawer]: that widget models a flat list of mutually
/// exclusive destinations with a selection state, which is wrong twice
/// over here — these entries `push` onto the current branch rather than
/// selecting a persistent destination, and the admin group needs a
/// labelled section break that [NavigationDrawer] has no room for.
class _AppDrawer extends StatelessWidget {
  const _AppDrawer({required this.isAdmin, required this.onSelect});

  final bool isAdmin;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Drawer(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(AppRadius.xl),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _DrawerHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                children: [
                  _DrawerItem(
                    icon: AppIcons.store,
                    label: 'Merchandise',
                    onTap: () => onSelect(AppConstants.routeMerchandise),
                  ),
                  _DrawerItem(
                    icon: AppIcons.challenges,
                    label: 'Challenges',
                    onTap: () => onSelect(AppConstants.routeChallenges),
                  ),
                  _DrawerItem(
                    icon: AppIcons.info,
                    label: 'About',
                    onTap: () => onSelect(AppConstants.routeAbout),
                  ),
                  _DrawerItem(
                    icon: AppIcons.support,
                    label: 'Support',
                    onTap: () => onSelect(AppConstants.routeSupport),
                  ),
                  _DrawerItem(
                    icon: AppIcons.settings,
                    label: 'Settings',
                    onTap: () => onSelect(AppConstants.routeSettings),
                  ),
                  _DrawerItem(
                    icon: AppIcons.connect,
                    label: 'Contact',
                    onTap: () => onSelect(AppConstants.routeContact),
                  ),

                  // ── Admin ───────────────────────────────────────────
                  // Rendered only for an admin. Gating the *affordance*
                  // here is presentation only — every one of these paths
                  // starts with /admin and is independently gated by the
                  // router's own admin redirect and by RLS, so hiding
                  // them is a courtesy, not the security boundary.
                  if (isAdmin) ...[
                    const _DrawerSectionBreak(label: 'Admin'),
                    _DrawerItem(
                      icon: AppIcons.registrations,
                      label: 'Registrations',
                      onTap: () =>
                          onSelect(AppConstants.routeAdminTrekRegistrations),
                    ),
                    _DrawerItem(
                      icon: AppIcons.store,
                      label: 'Merchandise Inquiries',
                      onTap: () =>
                          onSelect(AppConstants.routeAdminMerchInquiries),
                    ),
                    _DrawerItem(
                      icon: AppIcons.announce,
                      label: 'Send Notification',
                      onTap: () =>
                          onSelect(AppConstants.routeAdminSendNotification),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.md,
              ),
              child: Text(
                'v${AppConstants.appVersion}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: palette.textDisabled,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.primary,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: AppIcon(
              AppIcons.landscape,
              color: palette.onPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              AppConstants.appName,
              style: AppTextStyles.titleMedium.copyWith(
                color: palette.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled break between drawer groups — a hairline plus a quiet
/// overline, which is enough to separate without adding a heavy header.
class _DrawerSectionBreak extends StatelessWidget {
  const _DrawerSectionBreak({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: palette.border, height: 1),
          const SizedBox(height: AppSpacing.lg),
          Text(
            label.toUpperCase(),
            style: AppTextStyles.overline.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 2,
      ),
      child: Semantics(
        button: true,
        label: label,
        child: Pressable(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                AppIcon(icon, size: 22, color: palette.textSecondary),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.titleSmall.copyWith(
                      color: palette.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
