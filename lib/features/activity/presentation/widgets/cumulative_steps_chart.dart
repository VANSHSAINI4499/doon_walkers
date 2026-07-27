import 'dart:math' as math;
import 'package:doon_walkers/core/design_system.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Smooth cumulative steps line chart for Day View ("Today's progress").
class CumulativeStepsChart extends StatelessWidget {
  const CumulativeStepsChart({
    super.key,
    required this.totalSteps,
    required this.targetSteps,
  });

  final int totalSteps;
  final int targetSteps;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    // Create 6 simulated curve points building up to the total steps endpoint
    final points = <FlSpot>[
      const FlSpot(0, 0),
      FlSpot(1, totalSteps * 0.15),
      FlSpot(2, totalSteps * 0.35),
      FlSpot(3, totalSteps * 0.60),
      FlSpot(4, totalSteps * 0.85),
      FlSpot(5, totalSteps.toDouble()),
    ];

    final maxY = math.max(
      targetSteps.toDouble(),
      (totalSteps * 1.2).toDouble(),
    );

    return AspectRatio(
      aspectRatio: 2.2,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: 5,
          minY: 0,
          maxY: maxY == 0 ? 1000 : maxY,
          lineBarsData: [
            LineChartBarData(
              spots: points,
              isCurved: true,
              color: palette.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: palette.primary.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
