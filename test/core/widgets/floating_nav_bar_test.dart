// Widget-level coverage for the Phase 7 bottom nav chrome. AppShell's own
// resolveSelectedTabIndex tests (app_shell_selected_index_test.dart) own
// the crash-history-critical clamping logic and are untouched by this
// phase; these tests cover the NEW rendering widget that consumes an
// already-clamped index — that it renders the right tab count, marks the
// right one selected, and fires taps with the right index.

import 'package:doon_walkers/core/icons/app_icons.dart';
import 'package:doon_walkers/core/theme/app_theme.dart';
import 'package:doon_walkers/core/widgets/floating_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _destinations = [
  FloatingNavBarDestination(icon: AppIcons.home, label: 'Home'),
  FloatingNavBarDestination(icon: AppIcons.treks, label: 'Treks'),
  FloatingNavBarDestination(icon: AppIcons.challenges, label: 'Challenges'),
  FloatingNavBarDestination(icon: AppIcons.profile, label: 'Profile'),
];

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(bottomNavigationBar: child),
);

void main() {
  testWidgets('renders one tab per destination, all labels visible', (tester) async {
    await tester.pumpWidget(_host(
      FloatingNavBar(destinations: _destinations, selectedIndex: 0, onDestinationSelected: (_) {}),
    ));
    await tester.pump();

    for (final d in _destinations) {
      expect(find.text(d.label), findsOneWidget);
    }
  });

  testWidgets('tapping a tab reports its own index, not the currently-selected one', (tester) async {
    int? tapped;
    await tester.pumpWidget(_host(
      FloatingNavBar(
        destinations: _destinations,
        selectedIndex: 0,
        onDestinationSelected: (i) => tapped = i,
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('Challenges'));
    expect(tapped, 2);

    await tester.tap(find.text('Profile'));
    expect(tapped, 3);
  });

  testWidgets('the selected tab renders with a filled indicator, others without', (tester) async {
    await tester.pumpWidget(_host(
      FloatingNavBar(destinations: _destinations, selectedIndex: 1, onDestinationSelected: (_) {}),
    ));
    await tester.pump();

    // Pressable's own press-feedback AnimatedScale (90ms) is also in the
    // tree per tab — filter to just the icon-selection ones (260ms,
    // AppMotion.medium) to isolate what this test cares about.
    final scales = tester
        .widgetList<AnimatedScale>(find.byType(AnimatedScale))
        .where((s) => s.duration == const Duration(milliseconds: 260))
        .toList();
    expect(scales, hasLength(_destinations.length));
    // Index 1 (Treks) is selected → scaled up; every other tab is not.
    expect(scales[1].scale, greaterThan(scales[0].scale));
    expect(scales[1].scale, greaterThan(scales[2].scale));
  });

  testWidgets('reacts to a live selectedIndex change (role-transition-style rebuild)', (tester) async {
    Widget build(int selected, List<FloatingNavBarDestination> dest) => _host(
      FloatingNavBar(destinations: dest, selectedIndex: selected, onDestinationSelected: (_) {}),
    );

    await tester.pumpWidget(build(3, _destinations));
    await tester.pump();
    expect(find.text('Profile'), findsOneWidget);

    // Simulate a promotion: a 5th destination appears and selection stays
    // put — mirrors AppShell gaining the admin tab while already on Profile.
    final withAdmin = [
      ..._destinations,
      const FloatingNavBarDestination(icon: AppIcons.registrations, label: 'Registrations'),
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
  });
}
