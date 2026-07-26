// Guards the scenario this project's crash history is about: a LIVE role
// change while AppShell is already mounted.
//
// resolveSelectedTabIndex's own exhaustive test
// (app_shell_selected_index_test.dart) covers the pure clamping maths;
// this file mounts the REAL AppShell behind a minimal GoRouter mirroring
// the app's actual 6-branch shape and flips `isAdminProvider` while the
// widget tree stays alive.
//
// What changed in Redesign 2.0 Phase 10, and why these tests read
// differently from their predecessors: the bottom nav is now five shared
// tabs for EVERY role. Admin no longer gains or loses a tab, so the
// "tab set shrinks under the current selection" trigger is gone by
// construction. What remains to verify is that:
//   - the tab bar is genuinely role-independent (same five, always),
//   - the drawer is not (admin-only entries appear/disappear live),
//   - a demotion while sitting on the admin BRANCH still bounces Home,
//   - a demotion anywhere else leaves the user where they are.

import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/core/theme/app_theme.dart';
import 'package:doon_walkers/core/widgets/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Drives `isAdminProvider` for this test — flipped directly via the
/// `ProviderContainer` from outside the widget tree, exactly like a real
/// role change arriving over Supabase Realtime while the app is open.
final _demoIsAdmin = StateProvider<bool>((ref) => false);

class _Body extends StatelessWidget {
  const _Body(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Center(child: Text(label));
}

/// Mirrors app_router.dart's real branch order — **five branches, all
/// tabs**: 0 Home · 1 Activity · 2 Treks · 3 Challenges · 4 Profile.
///
/// There is deliberately no admin branch. Phase 10 moved every admin
/// screen out of the shell to a top-level route, so the shell has no
/// non-tab branch at all any more. The admin gating that used to be
/// tested through this shell now lives in
/// test/core/router/admin_route_guard_test.dart, where it actually runs.
GoRouter _buildTestRouter({required String initialLocation}) {
  StatefulShellBranch branch(String path, String label) => StatefulShellBranch(
    routes: [GoRoute(path: path, builder: (_, _) => _Body(label))],
  );

  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          branch(AppConstants.routeHome, 'HomeBody'),
          branch(AppConstants.routeActivity, 'ActivityBody'),
          branch(AppConstants.routeTrekLibrary, 'TreksBody'),
          branch(AppConstants.routeChallenges, 'ChallengesBody'),
          branch(AppConstants.routeProfile, 'ProfileBody'),
        ],
      ),
      // Top-level, outside the shell — exactly as the real router now
      // declares it. Pushed over the shell from the drawer.
      GoRoute(
        path: AppConstants.routeAdminTrekRegistrations,
        builder: (_, _) => const _Body('AdminBody'),
      ),
    ],
  );
}

Future<ProviderContainer> _pumpShell(
  WidgetTester tester, {
  required String initialLocation,
  required bool startAsAdmin,
  ThemeData? theme,
}) async {
  final container = ProviderContainer(
    overrides: [isAdminProvider.overrideWith((ref) => ref.watch(_demoIsAdmin))],
  );
  addTearDown(container.dispose);
  container.read(_demoIsAdmin.notifier).state = startAsAdmin;

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: theme ?? AppTheme.dark,
        routerConfig: _buildTestRouter(initialLocation: initialLocation),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// The five tab labels, in order.
const _tabLabels = ['Home', 'Activity', 'Treks', 'Challenges', 'Profile'];

void _expectAllFiveTabs() {
  for (final label in _tabLabels) {
    expect(
      find.text(label),
      findsOneWidget,
      reason: '"$label" must be present in the bottom nav',
    );
  }
}

Future<void> _openDrawer(WidgetTester tester) async {
  await tester.tap(find.byTooltip('More'));
  await tester.pumpAndSettle();
}

void main() {
  group('the tab bar is role-independent', () {
    testWidgets('a guest/member sees exactly the five shared tabs', (
      tester,
    ) async {
      await _pumpShell(
        tester,
        initialLocation: AppConstants.routeHome,
        startAsAdmin: false,
      );
      _expectAllFiveTabs();
      expect(find.text('Registrations'), findsNothing);
    });

    testWidgets('an admin sees the same five — no sixth tab', (tester) async {
      await _pumpShell(
        tester,
        initialLocation: AppConstants.routeHome,
        startAsAdmin: true,
      );
      _expectAllFiveTabs();
      // The core Phase 10 decision: Registrations is NOT a tab anymore.
      // It must not appear in the bar even for an admin.
      expect(find.text('Registrations'), findsNothing);
    });

    testWidgets('a live promotion does not change the tab bar at all', (
      tester,
    ) async {
      final container = await _pumpShell(
        tester,
        initialLocation: AppConstants.routeProfile,
        startAsAdmin: false,
      );
      _expectAllFiveTabs();
      expect(find.text('ProfileBody'), findsOneWidget);

      container.read(_demoIsAdmin.notifier).state = true;
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      _expectAllFiveTabs();
      expect(find.text('Registrations'), findsNothing);
      // Still on Profile — promotion must not disturb the current tab.
      expect(find.text('ProfileBody'), findsOneWidget);
    });

    testWidgets('a live demotion on a shared tab leaves the user alone', (
      tester,
    ) async {
      final container = await _pumpShell(
        tester,
        initialLocation: AppConstants.routeTrekLibrary,
        startAsAdmin: true,
      );
      expect(find.text('TreksBody'), findsOneWidget);

      container.read(_demoIsAdmin.notifier).state = false;
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Untouched — the redirect guard is scoped to the admin branch, not
      // to any demotion whatsoever.
      expect(find.text('TreksBody'), findsOneWidget);
      _expectAllFiveTabs();
    });
  });

  group('every tab navigates', () {
    testWidgets('tapping each tab reaches its own branch', (tester) async {
      await _pumpShell(
        tester,
        initialLocation: AppConstants.routeHome,
        startAsAdmin: false,
      );

      // Walks the whole bar, including the newly-inserted Activity tab —
      // this is what would catch a destinations/branches order mismatch,
      // which would otherwise show up as "tapping Treks opens Activity".
      const expectedBodies = [
        'HomeBody',
        'ActivityBody',
        'TreksBody',
        'ChallengesBody',
        'ProfileBody',
      ];

      for (var i = 0; i < _tabLabels.length; i++) {
        await tester.tap(find.text(_tabLabels[i]));
        await tester.pumpAndSettle();
        expect(
          find.text(expectedBodies[i]),
          findsOneWidget,
          reason: 'tapping "${_tabLabels[i]}" must open ${expectedBodies[i]}',
        );
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('the drawer is role-dependent', () {
    testWidgets('a member sees the shared entries and no Admin section', (
      tester,
    ) async {
      await _pumpShell(
        tester,
        initialLocation: AppConstants.routeHome,
        startAsAdmin: false,
      );
      await _openDrawer(tester);

      for (final label in [
        'Merchandise',
        'About',
        'Support',
        'Settings',
        'Contact',
      ]) {
        expect(find.text(label), findsOneWidget, reason: '"$label" missing');
      }
      expect(find.text('ADMIN'), findsNothing);
      expect(find.text('Registrations'), findsNothing);
    });

    testWidgets('an admin additionally sees the Admin section', (tester) async {
      await _pumpShell(
        tester,
        initialLocation: AppConstants.routeHome,
        startAsAdmin: true,
      );
      await _openDrawer(tester);

      expect(find.text('ADMIN'), findsOneWidget);
      // Registrations is reachable for an admin — via the drawer, which
      // is the whole point of the relocation.
      expect(find.text('Registrations'), findsOneWidget);
      expect(find.text('Merchandise Inquiries'), findsOneWidget);
      expect(find.text('Send Notification'), findsOneWidget);
    });

    testWidgets('the Admin section appears/disappears on a live role flip', (
      tester,
    ) async {
      final container = await _pumpShell(
        tester,
        initialLocation: AppConstants.routeHome,
        startAsAdmin: false,
      );
      await _openDrawer(tester);
      expect(find.text('Registrations'), findsNothing);

      container.read(_demoIsAdmin.notifier).state = true;
      await tester.pumpAndSettle();
      expect(find.text('Registrations'), findsOneWidget);

      container.read(_demoIsAdmin.notifier).state = false;
      await tester.pumpAndSettle();
      expect(find.text('Registrations'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('admin screens are outside the shell', () {
    testWidgets('Registrations opens over the shell, not as a tab', (
      tester,
    ) async {
      // The regression this pins: while the admin screens were a shell
      // BRANCH, the drawer's context.push() did not switch branches, so
      // the shell sat on whichever tab was underneath while showing
      // admin content — which silently disabled the demotion guard.
      // As a top-level route it takes over the screen properly, with no
      // bottom nav of its own.
      await _pumpShell(
        tester,
        initialLocation: AppConstants.routeAdminTrekRegistrations,
        startAsAdmin: true,
      );

      expect(find.text('AdminBody'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // No shell chrome: the tab bar must not be underneath it.
      for (final label in _tabLabels) {
        expect(
          find.text(label),
          findsNothing,
          reason:
              '"$label" must not render — an admin screen is a top-level '
              'route now, not a branch inside the shell',
        );
      }
    });
  });

  group('light theme', () {
    // The shell is chrome: if it only resolved colour correctly in dark,
    // every screen in the app would be framed wrong in light mode.
    testWidgets('the shell renders in light theme without throwing', (
      tester,
    ) async {
      await _pumpShell(
        tester,
        initialLocation: AppConstants.routeHome,
        startAsAdmin: true,
        theme: AppTheme.light,
      );
      _expectAllFiveTabs();
      expect(tester.takeException(), isNull);

      await _openDrawer(tester);
      expect(find.text('ADMIN'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
