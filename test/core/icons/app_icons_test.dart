import 'package:doon_walkers/core/icons/app_icons.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppIcons', () {
    test('every icon resolves to a valid Lucide icon', () {
      for (final entry in AppIcons.all.entries) {
        expect(
          entry.value.fontFamily,
          'Lucide',
          reason: 'AppIcons.${entry.key} does not resolve to Lucide font.',
        );
      }
    });

    test('every icon is provided by the lucide_icons_flutter package', () {
      for (final entry in AppIcons.all.entries) {
        expect(
          entry.value.fontPackage,
          'lucide_icons_flutter',
          reason:
              'AppIcons.${entry.key} is not from the lucide_icons_flutter package.',
        );
      }
    });

    test('the vocabulary has no duplicate names', () {
      final names = AppIcons.all.keys.toList();
      expect(names.length, names.toSet().length);
    });
  });

  group('AppIcon', () {
    testWidgets('renders Lucide Icon correctly', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: AppIcon(AppIcons.home),
        ),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
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
