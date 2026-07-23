// Verifies the two hard invariants of the redesign icon set:
//   1. every AppIcons entry is Material Symbols **Rounded** (not
//      outlined or sharp), and
//   2. AppIcon renders them **filled**.
//
// A typo like `Symbols.home` (outlined) instead of `Symbols.home_rounded`
// produces no visible error at a call site — the icon just quietly draws
// in the wrong style. This test is the guard against that.

import 'package:doon_walkers/core/icons/app_icons.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppIcons', () {
    test('every icon resolves to the MaterialSymbolsRounded font', () {
      for (final entry in AppIcons.all.entries) {
        expect(
          entry.value.fontFamily,
          AppIcons.fontFamily,
          reason: 'AppIcons.${entry.key} is not a Rounded symbol — it '
              'resolves to ${entry.value.fontFamily}. Use '
              'Symbols.<name>_rounded.',
        );
      }
    });

    test('every icon is provided by the material_symbols_icons package', () {
      for (final entry in AppIcons.all.entries) {
        expect(
          entry.value.fontPackage,
          'material_symbols_icons',
          reason: 'AppIcons.${entry.key} is not from the Material Symbols '
              'package.',
        );
      }
    });

    test('the vocabulary has no duplicate names', () {
      // The map literal itself would silently drop duplicate keys, so a
      // count check here catches an accidental repeated entry.
      final names = AppIcons.all.keys.toList();
      expect(names.length, names.toSet().length);
    });
  });

  group('AppIcon', () {
    testWidgets('renders filled by default (FILL axis = 1)', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: AppIcon(AppIcons.home),
        ),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.fill, 1);
      expect(icon.icon, AppIcons.home);
    });

    testWidgets('honours size and colour', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: AppIcon(AppIcons.streak, size: 40, color: Color(0xFFFB923C)),
        ),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.size, 40);
      expect(icon.color, const Color(0xFFFB923C));
    });
  });
}
