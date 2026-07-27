// Widget-level coverage for the Phase 7 bottom nav chrome. AppShell's own
// resolveSelectedTabIndex tests (app_shell_selected_index_test.dart) own
// the crash-history-critical clamping logic and are untouched by this
// phase; these tests cover the NEW rendering widget that consumes an
// already-clamped index — that it renders the right tab count, marks the
// right one selected, and fires taps with the right index.

import 'package:doon_walkers/core/icons/app_icons.dart';
import 'package:doon_walkers/core/theme/app_palette.dart';
import 'package:doon_walkers/core/theme/app_theme.dart';
import 'package:doon_walkers/core/widgets/floating_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _destinations = [
  FloatingNavBarDestination(icon: AppIcons.home, label: 'Home'),
  FloatingNavBarDestination(icon: AppIcons.steps, label: 'Activity'),
  FloatingNavBarDestination(icon: AppIcons.treks, label: 'Treks'),
  FloatingNavBarDestination(icon: AppIcons.group, label: 'Community'),
  FloatingNavBarDestination(icon: AppIcons.profile, label: 'Profile'),
];

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(bottomNavigationBar: child),
);

void main() {
  testWidgets('renders one tab per destination, all labels visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        FloatingNavBar(
          destinations: _destinations,
          selectedIndex: 0,
          onDestinationSelected: (_) {},
        ),
      ),
    );
    await tester.pump();

    for (final d in _destinations) {
      expect(find.text(d.label), findsOneWidget);
    }
  });

  testWidgets(
    'tapping a tab reports its own index, not the currently-selected one',
    (tester) async {
      int? tapped;
      await tester.pumpWidget(
        _host(
          FloatingNavBar(
            destinations: _destinations,
            selectedIndex: 0,
            onDestinationSelected: (i) => tapped = i,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Community'));
      expect(tapped, 3);

      await tester.tap(find.text('Profile'));
      expect(tapped, 4);
    },
  );

  testWidgets(
    'the selected tab renders with a filled indicator, others without',
    (tester) async {
      await tester.pumpWidget(
        _host(
          FloatingNavBar(
            destinations: _destinations,
            selectedIndex: 1,
            onDestinationSelected: (_) {},
          ),
        ),
      );
      await tester.pump();

      // The calm redesign carries selection as a filled pill behind the
      // icon, not as a scaled-up icon plus a glow — so this asserts on the
      // indicator's fill. (It previously counted 260ms AnimatedScales,
      // which the nav bar no longer has.)
      final indicators =
          tester
              .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
              .map((c) => c.decoration as BoxDecoration?)
              .toList();
      expect(indicators, hasLength(_destinations.length));

      const palette = AppPalette.dark;
      expect(
        indicators[1]?.color,
        palette.primarySubtle,
        reason: 'the selected tab must carry the indicator fill',
      );
      for (final i in [0, 2, 3]) {
        expect(
          indicators[i]?.color,
          Colors.transparent,
          reason: 'unselected tab $i must have no indicator fill',
        );
      }
    },
  );

  testWidgets('the nav bar draws no glow and no blur', (tester) async {
    // Both were defining features of the old floating glass pill. Their
    // absence is the point of the restyle, so pin it.
    await tester.pumpWidget(
      _host(
        FloatingNavBar(
          destinations: _destinations,
          selectedIndex: 0,
          onDestinationSelected: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(BackdropFilter), findsNothing);
    final withShadows = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .where((c) => (c.decoration as BoxDecoration?)?.boxShadow != null);
    expect(withShadows, isEmpty);
  });

  testWidgets(
    'reacts to a live selectedIndex change (role-transition-style rebuild)',
    (tester) async {
      Widget build(int selected, List<FloatingNavBarDestination> dest) => _host(
        FloatingNavBar(
          destinations: dest,
          selectedIndex: selected,
          onDestinationSelected: (_) {},
        ),
      );

      await tester.pumpWidget(build(3, _destinations));
      await tester.pump();
      expect(find.text('Profile'), findsOneWidget);

      // Simulate a promotion: a 5th destination appears and selection stays
      // put — mirrors AppShell gaining the admin tab while already on Profile.
      final withAdmin = [
        ..._destinations,
        const FloatingNavBarDestination(
          icon: AppIcons.registrations,
          label: 'Registrations',
        ),
      ];
      await tester.pumpWidget(build(3, withAdmin));
      await tester.pump();
      expect(find.text('Registrations'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      // Simulate a demotion back down — must not throw even though the
      // widget is rebuilt with fewer destinations while mounted.
      await tester.pumpWidget(build(0, _destinations));
      await tester.pump();
      expect(find.text('Registrations'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
