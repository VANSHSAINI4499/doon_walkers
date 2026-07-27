import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/activity/domain/entities/daily_activity.dart';
import 'package:doon_walkers/features/activity/domain/services/activity_period.dart';
import 'package:doon_walkers/features/activity/domain/services/activity_summary.dart';
import 'package:doon_walkers/features/activity/presentation/widgets/activity_views.dart';
import 'package:doon_walkers/features/activity/presentation/widgets/activity_rings.dart';
import 'package:doon_walkers/features/activity/presentation/widgets/cumulative_steps_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 20 Activity UI Tests', () {
    test('DailyActivity entity holds activeMinutes', () {
      final activity = DailyActivity(
        date: DateTime(2026, 7, 26),
        steps: 8500,
        distanceKm: 6.2,
        calories: 420.0,
        activeMinutes: 45,
      );

      expect(activity.steps, 8500);
      expect(activity.distanceKm, 6.2);
      expect(activity.calories, 420.0);
      expect(activity.activeMinutes, 45);
    });

    test('ActivitySummary calculates totalActiveMinutes correctly', () {
      final period = ActivityPeriod.week(DateTime(2026, 7, 26));
      final rows = [
        DailyActivity(
          date: DateTime(2026, 7, 20),
          steps: 5000,
          distanceKm: 3.5,
          calories: 250.0,
          activeMinutes: 30,
        ),
        DailyActivity(
          date: DateTime(2026, 7, 21),
          steps: 7000,
          distanceKm: 5.0,
          calories: 350.0,
          activeMinutes: 40,
        ),
      ];

      final summary = ActivitySummary.from(period, rows);
      expect(summary.totalActiveMinutes, 70);
      expect(summary.totalSteps, 12000);
      expect(summary.daysWithData, 2);
    });

    testWidgets('ActivityRings renders concentric rings CustomPaint', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: ActivityRings(
              stepsProgress: 0.8,
              caloriesProgress: 0.6,
              activeTimeProgress: 0.5,
            ),
          ),
        ),
      );

      expect(find.byType(ActivityRings), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('CumulativeStepsChart renders without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: CumulativeStepsChart(totalSteps: 8500, targetSteps: 10000),
          ),
        ),
      );

      expect(find.byType(CumulativeStepsChart), findsOneWidget);
      expect(
        find.text("Cumulative steps curve"),
        findsNothing,
      ); // Parent renders label
    });
  });
}
