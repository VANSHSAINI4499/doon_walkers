import 'dart:math' as math;

import 'package:doon_walkers/core/motion/app_motion.dart';
import 'package:doon_walkers/core/theme/app_dimens.dart';
import 'package:doon_walkers/core/theme/app_palette.dart';
import 'package:doon_walkers/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// A **flat, rounded progress bar** that animates to its value.
///
/// Deliberately plain: a solid track, a solid fill, fully rounded ends.
/// The old system would have gradient-filled and glowed this; the calm
/// version lets the accent colour alone carry the signal.
///
/// Animating to the value (rather than snapping) is one of the four
/// sanctioned motions. It also makes a change legible — a bar that jumps
/// tells you the new value, a bar that moves tells you it *changed*.
///
/// ```dart
/// AppProgressBar(value: 0.62, label: '62% to Gold')
/// ```
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.color,
    this.trackColor,
    this.height = 8,
    this.label,
    this.trailing,
    this.duration = AppMotion.slow,
  });

  /// Progress in 0–1. Values outside the range are clamped, so a caller
  /// that divides by a stale total can't paint outside the track.
  final double value;

  /// Fill colour. Defaults to the palette's primary.
  final Color? color;

  /// Track colour. Defaults to the palette's raised surface.
  final Color? trackColor;

  final double height;

  /// Optional caption above the bar, on the left.
  final String? label;

  /// Optional caption above the bar, on the right — typically the value
  /// as text ("3 of 5").
  final String? trailing;

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final fill = color ?? palette.primary;
    final clamped = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null || trailing != null) ...[
          Row(
            children: [
              if (label != null)
                Expanded(
                  child: Text(
                    label!,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: palette.textPrimary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: clamped),
          duration: duration,
          curve: AppMotion.emphasized,
          builder:
              (context, v, _) => ClipRRect(
                borderRadius: BorderRadius.circular(height),
                child: SizedBox(
                  height: height,
                  child: Stack(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: trackColor ?? palette.cardHigh,
                        ),
                        child: const SizedBox.expand(),
                      ),
                      FractionallySizedBox(
                        widthFactor: v,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: fill),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ),
      ],
    );
  }
}

/// A **circular progress ring** with room for content in the middle.
///
/// The natural companion to [StatDisplay]: put the hero number inside the
/// ring and the screen has exactly one focal point that is both the value
/// and its progress.
///
/// ```dart
/// AppProgressRing(
///   value: 0.62,
///   child: StatDisplay(value: '62', unit: '%', size: StatSize.large),
/// )
/// ```
class AppProgressRing extends StatelessWidget {
  const AppProgressRing({
    super.key,
    required this.value,
    this.size = 160,
    this.strokeWidth = 10,
    this.color,
    this.trackColor,
    this.child,
    this.duration = AppMotion.slow,
  });

  /// Progress in 0–1, clamped.
  final double value;

  final double size;
  final double strokeWidth;

  /// Ring colour. Defaults to the palette's primary.
  final Color? color;

  /// Track colour. Defaults to the palette's raised surface.
  final Color? trackColor;

  /// Centred content — usually a [StatDisplay].
  final Widget? child;

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final clamped = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: clamped),
        duration: duration,
        curve: AppMotion.emphasized,
        builder:
            (context, v, child) => CustomPaint(
              painter: _RingPainter(
                value: v,
                color: color ?? palette.primary,
                trackColor: trackColor ?? palette.cardHigh,
                strokeWidth: strokeWidth,
              ),
              child: Center(child: child),
            ),
        child: child,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double value;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final track =
        Paint()
          ..color = trackColor
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke;

    final fill =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          // Rounded caps so a small value reads as a soft tick rather than a
          // sharp wedge — the same softness as every corner in the system.
          ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, track);

    if (value > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        // Start at 12 o'clock and run clockwise, which is how people
        // read a dial.
        -math.pi / 2,
        2 * math.pi * value,
        false,
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}
