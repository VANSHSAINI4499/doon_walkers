import 'dart:math' as math;
import 'package:doon_walkers/core/design_system.dart';
import 'package:flutter/material.dart';

/// Concentric 3-ring Activity Rings component (Steps, Calories/Move, Active Time).
class ActivityRings extends StatelessWidget {
  const ActivityRings({
    super.key,
    required this.stepsProgress,
    required this.caloriesProgress,
    required this.activeTimeProgress,
    this.size = 180,
    this.strokeWidth = 14,
  });

  final double stepsProgress; // 0.0 .. 1.0+
  final double caloriesProgress; // 0.0 .. 1.0+
  final double activeTimeProgress; // 0.0 .. 1.0+
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ConcentricRingsPainter(
          stepsProgress: stepsProgress.clamp(0.0, 1.0),
          caloriesProgress: caloriesProgress.clamp(0.0, 1.0),
          activeTimeProgress: activeTimeProgress.clamp(0.0, 1.0),
          outerColor: palette.primary,
          middleColor: const Color(0xFFFF6B6B),
          innerColor: const Color(0xFF4ECDC4),
          trackColor: palette.cardHigh,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _ConcentricRingsPainter extends CustomPainter {
  const _ConcentricRingsPainter({
    required this.stepsProgress,
    required this.caloriesProgress,
    required this.activeTimeProgress,
    required this.outerColor,
    required this.middleColor,
    required this.innerColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double stepsProgress;
  final double caloriesProgress;
  final double activeTimeProgress;
  final Color outerColor;
  final Color middleColor;
  final Color innerColor;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final gap = strokeWidth + 4;

    _drawRing(
      canvas,
      center,
      radius: (size.width / 2) - (strokeWidth / 2),
      progress: stepsProgress,
      color: outerColor,
    );

    _drawRing(
      canvas,
      center,
      radius: (size.width / 2) - (strokeWidth / 2) - gap,
      progress: caloriesProgress,
      color: middleColor,
    );

    _drawRing(
      canvas,
      center,
      radius: (size.width / 2) - (strokeWidth / 2) - (gap * 2),
      progress: activeTimeProgress,
      color: innerColor,
    );
  }

  void _drawRing(
    Canvas canvas,
    Offset center, {
    required double radius,
    required double progress,
    required Color color,
  }) {
    if (radius <= 0) return;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConcentricRingsPainter oldDelegate) {
    return oldDelegate.stepsProgress != stepsProgress ||
        oldDelegate.caloriesProgress != caloriesProgress ||
        oldDelegate.activeTimeProgress != activeTimeProgress ||
        oldDelegate.outerColor != outerColor ||
        oldDelegate.middleColor != middleColor ||
        oldDelegate.innerColor != innerColor;
  }
}
