import 'package:doon_walkers/core/theme/app_theme.dart';
import 'package:doon_walkers/features/design_demo/presentation/screens/design_system_demo_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DesignSystemDemoScreen lays out with no overflow', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: const DesignSystemDemoScreen(),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);

    // Scroll through the whole thing to force every sliver child to build.
    final scrollable = find.byType(Scrollable).first;
    for (var i = 0; i < 8; i++) {
      await tester.drag(scrollable, const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull, reason: 'overflow at scroll step $i');
    }
    await tester.pumpWidget(const SizedBox());
  });
}
