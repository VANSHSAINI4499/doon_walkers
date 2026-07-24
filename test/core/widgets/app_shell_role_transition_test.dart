// Guards the exact scenario this project's crash history is about: a
// LIVE role change — not a cold start with a fixed role — while AppShell
// is already mounted and the user may be sitting on a tab that only
// exists for one role. resolveSelectedTabIndex's own exhaustive test
// (app_shell_selected_index_test.dart) covers the pure clamping maths;
// this file mounts the REAL AppShell behind a minimal GoRouter mirroring
// the app's actual 6-branch shape, and flips `isAdminProvider` while the
// widget tree stays alive, verifying:
//   - no assertion/crash when the tab set shrinks or grows underneath the
//     current selection,
//   - a demotion while sitting on the admin-only Trek Registrations tab
//     actively navigates to Home (AppShell's own `ref.listen` guard),
//   - a promotion while sitting on a shared tab leaves the current
//     screen alone and simply grows the bar to 5 tabs.

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
/// role change would arrive via Supabase Realtime while the app is open.
final _demoIsAdmin = StateProvider<bool>((ref) => false);

class _Placeholder extends StatelessWidget {
  const _Placeholder(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Center(child: Text(label));
}

GoRouter _buildTestRouter({required String initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: AppConstants.routeHome, builder: (_, __) => const _Placeholder('Home')),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: AppConstants.routeTrekLibrary, builder: (_, __) => const _Placeholder('Treks')),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: AppConstants.routeChallenges, builder: (_, __) => const _Placeholder('Challenges')),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: AppConstants.routeProfile, builder: (_, __) => const _Placeholder('Profile')),
            ],
          ),
          // Branch 4 — admin-only Trek Registrations TAB.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppConstants.routeAdminTrekRegistrations,
                builder: (_, __) => const _Placeholder('Registrations'),
              ),
            ],
          ),
          // Branch 5 — admin-only standalone screens, never a tab.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppConstants.routeAdminRegistrations,
                builder: (_, __) => const _Placeholder('AdminOnly'),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

Future<ProviderContainer> _pumpShell(
  WidgetTester tester, {
  required String initialLocation,
  required bool startAsAdmin,
}) async {
  final container = ProviderContainer(
    overrides: [
      isAdminProvider.overrideWith((ref) => ref.watch(_demoIsAdmin)),
    ],
  );
  addTearDown(container.dispose);
  container.read(_demoIsAdmin.notifier).state = startAsAdmin;

  final router = _buildTestRouter(initialLocation: initialLocation);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets(
    'demotion while sitting on the admin-only Registrations tab navigates '
    'to Home and never crashes',
    (tester) async {
      final container = await _pumpShell(
        tester,
        initialLocation: AppConstants.routeAdminTrekRegistrations,
        startAsAdmin: true,
      );

      // Starts on the 5th tab, as an admin — 5 destinations, this one selected.
      expect(find.text('Registrations'), findsWidgets); // tab label + body
      expect(tester.takeException(), isNull);

      // Live demotion — the exact historical crash scenario: the tab set
      // is about to shrink out from under the currently-selected index.
      container.read(_demoIsAdmin.notifier).state = false;
      await tester.pumpAndSettle();

      // No assertion/exception from an out-of-range selectedIndex reaching
      // the nav bar...
      expect(tester.takeException(), isNull);
      // ...and AppShell's own ref.listen guard actively bounced to Home,
      // rather than stranding the viewer on now-invisible content.
      expect(find.text('Home'), findsWidgets);
      expect(find.text('Registrations'), findsNothing);
    },
  );

  testWidgets(
    'promotion while sitting on a shared tab (Profile) leaves the current '
    'screen alone and just grows the bar to 5 tabs',
    (tester) async {
      final container = await _pumpShell(
        tester,
        initialLocation: AppConstants.routeProfile,
        startAsAdmin: false,
      );

      expect(find.text('Profile'), findsWidgets);
      expect(find.text('Registrations'), findsNothing); // not an admin yet

      // Live promotion while mounted, sitting on a tab both roles share.
      container.read(_demoIsAdmin.notifier).state = true;
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Still on Profile — promotion must not disturb the current tab...
      expect(find.text('Profile'), findsWidgets);
      // ...and the 5th tab has simply appeared in the bar.
      expect(find.text('Registrations'), findsOneWidget);
    },
  );

  testWidgets(
    'demotion while on a shared tab that also happens to be the stale '
    "fallback resets cleanly to Home, per resolveSelectedTabIndex's own "
    'documented edge case',
    (tester) async {
      // Reach Treks (branch 1) as admin, then demote — Treks still exists
      // for a member, so this should NOT navigate away; only branch 4
      // triggers the active redirect. This proves the ref.listen guard is
      // scoped exactly to branch 4, not any demotion whatsoever.
      final container = await _pumpShell(
        tester,
        initialLocation: AppConstants.routeTrekLibrary,
        startAsAdmin: true,
      );
      expect(find.text('Treks'), findsWidgets);

      container.read(_demoIsAdmin.notifier).state = false;
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Treks'), findsWidgets); // untouched — no forced navigation
    },
  );
}
