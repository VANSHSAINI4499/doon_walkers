// Smoke + behaviour tests for the calm design system foundation. These
// are the pieces every screen builds on, so a regression here is a
// regression everywhere.
//
// Most cases run against **both** themes: the whole point of the
// foundation rewrite is that a component resolves its own colour off the
// active palette, and a test that only ever pumps one theme would not
// catch a hardcoded colour sneaking back in.

import 'package:doon_walkers/core/theme/app_palette.dart';
import 'package:doon_walkers/core/theme/app_theme.dart';
import 'package:doon_walkers/core/widgets/app_progress.dart';
import 'package:doon_walkers/core/widgets/glass_card.dart';
import 'package:doon_walkers/core/widgets/premium_button.dart';
import 'package:doon_walkers/core/widgets/skeleton.dart';
import 'package:doon_walkers/core/widgets/stat_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

// Scrollable so tall stacks of skeletons don't overflow the test
// viewport (which would throw a RenderFlex overflow and fail the pump).
Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.dark,
  home: Scaffold(body: SingleChildScrollView(child: Center(child: child))),
);

/// Runs [body] once per theme so colour-resolution bugs surface in both.
///
/// The theme is passed as a *factory*, not a value. Building `AppTheme`
/// eagerly here would construct it at test-registration time — outside
/// any test zone — and `AppTextStyles` goes through google_fonts, which
/// then tries to fetch over the network and fails the whole file at load
/// with "There is no current invoker". Keep it lazy.
void _inBothThemes(
  String description,
  Future<void> Function(
    WidgetTester tester,
    ThemeData theme,
    AppPalette palette,
  )
  body,
) {
  for (final (name, theme, palette)
      in <(String, ThemeData Function(), AppPalette)>[
        ('light', () => AppTheme.light, AppPalette.light),
        ('dark', () => AppTheme.dark, AppPalette.dark),
      ]) {
    testWidgets(
      '$description ($name)',
      (tester) => body(tester, theme(), palette),
    );
  }
}

void main() {
  // Widget tests have no network. Without this, every style built from
  // google_fonts attempts a fetch, logs a failure and falls back to the
  // system font; pinning it off makes the fallback explicit and silent.
  GoogleFonts.config.allowRuntimeFetching = false;

  group('AppPalette', () {
    test('light and dark are distinct and correctly branded', () {
      expect(AppPalette.light.brightness, Brightness.light);
      expect(AppPalette.dark.brightness, Brightness.dark);
      expect(AppPalette.light.background, isNot(AppPalette.dark.background));
    });

    test('dark surfaces lift toward grey, never toward black', () {
      // The dark theme is the one where "forward" genuinely means
      // lighter, and where the old system's near-black page made borders
      // and soft shadows invisible. Pin the direction.
      const p = AppPalette.dark;
      final steps = [p.background, p.surface, p.card, p.cardHigh];
      final luminance = steps.map((c) => c.computeLuminance()).toList();
      for (var i = 1; i < luminance.length; i++) {
        expect(
          luminance[i],
          greaterThan(luminance[i - 1]),
          reason: 'dark surface step $i did not lift',
        );
      }
      expect(
        p.background.computeLuminance(),
        greaterThan(0.0),
        reason: 'the page must not be pure black',
      );
    });

    test('every surface step is distinguishable from its neighbour', () {
      // Light mode tops out at white and then goes slightly grey for
      // cardHigh, so luminance is not monotonic there — see AppPalette's
      // doc. What must hold in *both* themes is that adjacent steps are
      // actually different, or the layering model conveys nothing.
      for (final p in [AppPalette.light, AppPalette.dark]) {
        final steps = <(String, Color)>[
          ('background', p.background),
          ('surface', p.surface),
          ('card', p.card),
          ('cardHigh', p.cardHigh),
        ];
        for (var i = 1; i < steps.length; i++) {
          final (prevName, prev) = steps[i - 1];
          final (name, current) = steps[i];
          // surface and card are allowed to coincide (a sheet and a card
          // are the same plane); the ends of the ramp are not.
          if (prevName == 'surface' && name == 'card') continue;
          expect(
            current,
            isNot(prev),
            reason: '$name == $prevName in ${p.brightness}',
          );
        }
        expect(
          (p.background.computeLuminance() - p.cardHigh.computeLuminance())
              .abs(),
          greaterThan(0.02),
          reason: 'page and topmost surface too close in ${p.brightness}',
        );
      }
    });

    testWidgets('resolves off the theme extension', (tester) async {
      late AppPalette resolved;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              resolved = AppPalette.of(context);
              return const SizedBox();
            },
          ),
          theme: AppTheme.light,
        ),
      );
      expect(resolved.brightness, Brightness.light);
    });

    testWidgets('falls back to dark when no extension is registered', (
      tester,
    ) async {
      late AppPalette resolved;
      await tester.pumpWidget(
        MaterialApp(
          // Bare ThemeData — no AppPalette extension.
          theme: ThemeData(),
          home: Builder(
            builder: (context) {
              resolved = AppPalette.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(resolved, AppPalette.dark);
    });
  });

  group('AppCard', () {
    testWidgets('renders its child', (tester) async {
      await tester.pumpWidget(_host(const AppCard(child: Text('hello'))));
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('fires onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(AppCard(onTap: () => taps++, child: const Text('tap me'))),
      );
      await tester.tap(find.text('tap me'));
      expect(taps, 1);
    });

    testWidgets('never paints a BackdropFilter — glass is retired', (
      tester,
    ) async {
      // The old card stacked a blur behind every surface. Asserting its
      // absence (rather than its presence, as the pre-rewrite test did)
      // is what keeps frosted glass from creeping back in.
      await tester.pumpWidget(_host(const AppCard(child: Text('x'))));
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('GlassCard is still constructible and is an AppCard', (
      tester,
    ) async {
      // ~58 files still say GlassCard. They must keep working and must
      // get the calm treatment, not a second implementation.
      await tester.pumpWidget(_host(const GlassCard(child: Text('legacy'))));
      expect(find.text('legacy'), findsOneWidget);
      expect(find.byType(AppCard), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('retired blur/glow parameters are accepted and ignored', (
      tester,
    ) async {
      // The compatibility contract: passing them must not throw, must not
      // blur, and must not change the card's look.
      await tester.pumpWidget(
        _host(
          const GlassCard(
            blurEnabled: true,
            blur: 30,
            glowColor: Colors.pink,
            glowOpacity: 0.9,
            child: Text('compat'),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(BackdropFilter), findsNothing);
    });

    _inBothThemes('fills from the active palette', (
      tester,
      theme,
      palette,
    ) async {
      await tester.pumpWidget(
        _host(const AppCard(child: Text('x')), theme: theme),
      );
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(AppCard),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, palette.card);
    });

    testWidgets('PulsingGlassCard renders statically without throwing', (
      tester,
    ) async {
      // The pulse is retired — this must now settle, which the old
      // repeating-controller version never could.
      await tester.pumpWidget(
        _host(const PulsingGlassCard(child: Text('live'))),
      );
      expect(find.text('live'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('AppButton', () {
    testWidgets('fires onPressed when enabled', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        _host(AppButton(label: 'Go', onPressed: () => pressed++)),
      );
      await tester.tap(find.text('Go'));
      expect(pressed, 1);
    });

    testWidgets('does nothing when disabled (onPressed null)', (tester) async {
      await tester.pumpWidget(
        _host(const AppButton(label: 'Nope', onPressed: null)),
      );
      await tester.tap(find.text('Nope'));
      // No callback to assert; the tap must simply not throw.
      expect(find.text('Nope'), findsOneWidget);
    });

    testWidgets('ignores taps and shows a spinner while loading', (
      tester,
    ) async {
      var pressed = 0;
      await tester.pumpWidget(
        _host(
          AppButton(
            label: 'Submit',
            isLoading: true,
            onPressed: () => pressed++,
          ),
        ),
      );
      await tester.tap(find.byType(AppButton));
      expect(pressed, 0, reason: 'a loading button must not re-submit');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('label stays in the tree while loading (no reflow)', (
      tester,
    ) async {
      // The label is faded to 0 opacity rather than removed, so the
      // button keeps its width.
      await tester.pumpWidget(
        _host(AppButton(label: 'Register', isLoading: true, onPressed: () {})),
      );
      expect(find.text('Register'), findsOneWidget);
    });

    testWidgets('icon-only variant builds', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        _host(AppButton.icon(icon: Icons.add, onPressed: () => pressed++)),
      );
      await tester.tap(find.byType(AppButton));
      expect(pressed, 1);
    });

    testWidgets('PremiumButton typedef still constructs', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        _host(
          PremiumButton(
            label: 'Legacy',
            variant: PremiumButtonVariant.primary,
            size: PremiumButtonSize.large,
            onPressed: () => pressed++,
          ),
        ),
      );
      await tester.tap(find.text('Legacy'));
      expect(pressed, 1);
    });

    _inBothThemes('primary fill comes from the active palette', (
      tester,
      theme,
      palette,
    ) async {
      await tester.pumpWidget(
        _host(AppButton(label: 'Go', onPressed: () {}), theme: theme),
      );
      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, palette.primary);
      // The glow is gone — a filled button casts no shadow of its own.
      expect(decoration.boxShadow, isNull);
    });
  });

  group('StatDisplay', () {
    testWidgets('renders eyebrow, value and label', (tester) async {
      await tester.pumpWidget(
        _host(
          const StatDisplay(value: '8,432', eyebrow: 'Today', label: 'steps'),
        ),
      );
      expect(find.text('TODAY'), findsOneWidget, reason: 'eyebrow uppercases');
      expect(find.text('8,432'), findsOneWidget);
      expect(find.text('steps'), findsOneWidget);
    });

    testWidgets('renders a unit alongside the value', (tester) async {
      await tester.pumpWidget(_host(const StatDisplay(value: '62', unit: '%')));
      expect(find.text('62'), findsOneWidget);
      expect(find.text('%'), findsOneWidget);
    });

    testWidgets('AnimatedStatDisplay counts up to its value', (tester) async {
      await tester.pumpWidget(_host(const AnimatedStatDisplay(value: 100)));
      // Mid-flight it must be showing something below the target.
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('100'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('StatRow lays out every stat with dividers between', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 340,
            child: StatRow(
              stats: [
                StatDisplay(value: '12', label: 'treks'),
                StatDisplay(value: '86', label: 'km'),
                StatDisplay(value: '5', label: 'badges'),
              ],
            ),
          ),
        ),
      );
      expect(find.text('12'), findsOneWidget);
      expect(find.text('86'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.byType(VerticalDivider), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });

  group('Progress', () {
    testWidgets('AppProgressBar renders its captions', (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 300,
            child: AppProgressBar(
              value: 0.5,
              label: 'Progress',
              trailing: '50%',
            ),
          ),
        ),
      );
      expect(find.text('Progress'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('AppProgressBar clamps out-of-range and non-finite values', (
      tester,
    ) async {
      // A caller dividing by a stale total must not paint outside the
      // track or crash the frame.
      for (final v in [-1.0, 2.0, double.nan, double.infinity]) {
        await tester.pumpWidget(
          _host(SizedBox(width: 300, child: AppProgressBar(value: v))),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'failed on value $v');
      }
    });

    testWidgets('AppProgressRing renders centred content', (tester) async {
      await tester.pumpWidget(
        _host(
          const AppProgressRing(
            value: 0.62,
            child: StatDisplay(value: '62', unit: '%'),
          ),
        ),
      );
      expect(find.text('62'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('Skeletons', () {
    testWidgets('SkeletonList builds under a single Shimmer', (tester) async {
      await tester.pumpWidget(
        _host(const SizedBox(width: 320, child: SkeletonList())),
      );
      // One shimmer sweep for the whole list, not one per card.
      expect(find.byType(Shimmer), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(_host(const SizedBox()));
    });

    testWidgets('Shimmer(enabled: false) skips the animated ShaderMask', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const Shimmer(enabled: false, child: SkeletonBox(width: 100))),
      );
      expect(find.byType(ShaderMask), findsNothing);
    });

    _inBothThemes('SkeletonBox fills from the active palette', (
      tester,
      theme,
      palette,
    ) async {
      await tester.pumpWidget(
        _host(const SkeletonBox(width: 100), theme: theme),
      );
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, palette.skeletonBase);
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
