// DoonWalkers widget tests — Phase 1 skeleton.
//
// Real tests will be added feature-by-feature. This file exists to
// confirm the test harness boots without errors.

import 'package:doon_walkers/core/widgets/coming_soon_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ComingSoonScreen renders without crashing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ComingSoonScreen(featureName: 'Test Feature'),
      ),
    );
    expect(find.text('Test Feature'), findsOneWidget);
    expect(find.text('This feature is coming soon.\nStay tuned for updates!'), findsOneWidget);
  });
}
