// Smoke + behaviour tests for the Redesign Phase 1 components. These are
// the pieces every later phase builds on, so a regression here is a
// regression everywhere.

import 'package:doon_walkers/core/theme/app_theme.dart';
import 'package:doon_walkers/core/widgets/glass_card.dart';
import 'package:doon_walkers/core/widgets/premium_button.dart';
import 'package:doon_walkers/core/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Scrollable so tall stacks of skeletons don't overflow the test
// viewport (which would throw a RenderFlex overflow and fail the pump).
Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(
    body: SingleChildScrollView(
      child: Center(child: child),
    ),
  ),
);

void main() {
  group('GlassCard', () {
    testWidgets('renders its child', (tester) async {
      await tester.pumpWidget(_host(const GlassCard(child: Text('hello'))));
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('fires onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(GlassCard(onTap: () => taps++, child: const Text('tap me'))),
      );
      await tester.tap(find.text('tap me'));
      expect(taps, 1);
    });

    testWidgets('opaque fallback drops the BackdropFilter when blur is off',
        (tester) async {
      await tester.pumpWidget(
        _host(const GlassCard(blurEnabled: false, child: Text('x'))),
      );
      expect(find.byType(BackdropFilter), findsNothing);

      await tester.pumpWidget(
        _host(const GlassCard(child: Text('x'))),
      );
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('PulsingGlassCard animates without throwing', (tester) async {
      await tester.pumpWidget(
        _host(const PulsingGlassCard(child: Text('live'))),
      );
      expect(find.text('live'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      // A repeating controller never settles, so let the test tear down
      // cleanly rather than pumpAndSettle (which would time out).
      await tester.pumpWidget(_host(const SizedBox()));
    });
  });

  group('PremiumButton', () {
    testWidgets('fires onPressed when enabled', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        _host(PremiumButton(label: 'Go', onPressed: () => pressed++)),
      );
      await tester.tap(find.text('Go'));
      expect(pressed, 1);
    });

    testWidgets('does nothing when disabled (onPressed null)', (tester) async {
      await tester.pumpWidget(
        _host(const PremiumButton(label: 'Nope', onPressed: null)),
      );
      await tester.tap(find.text('Nope'));
      // No callback to assert; the tap must simply not throw.
      expect(find.text('Nope'), findsOneWidget);
    });

    testWidgets('ignores taps and shows a spinner while loading',
        (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        _host(
          PremiumButton(
            label: 'Submit',
            isLoading: true,
            onPressed: () => pressed++,
          ),
        ),
      );
      await tester.tap(find.byType(PremiumButton));
      expect(pressed, 0, reason: 'a loading button must not re-submit');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('label stays in the tree while loading (no reflow)',
        (tester) async {
      // The label is faded to 0 opacity rather than removed, so the
      // button keeps its width. Assert the Text is still present.
      await tester.pumpWidget(
        _host(
          PremiumButton(label: 'Register', isLoading: true, onPressed: () {}),
        ),
      );
      expect(find.text('Register'), findsOneWidget);
    });

    testWidgets('icon-only variant builds', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        _host(
          PremiumButton.icon(
            icon: Icons.add,
            onPressed: () => pressed++,
          ),
        ),
      );
      await tester.tap(find.byType(PremiumButton));
      expect(pressed, 1);
    });
  });

  group('Skeletons', () {
    testWidgets('SkeletonList builds under a single Shimmer', (tester) async {
      await tester.pumpWidget(_host(const SizedBox(width: 320, child: SkeletonList())));
      // One shimmer sweep for the whole list, not one per card.
      expect(find.byType(Shimmer), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(_host(const SizedBox()));
    });

    testWidgets('Shimmer(enabled: false) skips the animated ShaderMask',
        (tester) async {
      await tester.pumpWidget(
        _host(const Shimmer(enabled: false, child: SkeletonBox(width: 100))),
      );
      expect(find.byType(ShaderMask), findsNothing);
    });

    testWidgets('composite skeletons render', (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SkeletonCardPlaceholder(),
                SkeletonStatRow(),
                SkeletonTileList(count: 2),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(_host(const SizedBox()));
    });
  });
}
