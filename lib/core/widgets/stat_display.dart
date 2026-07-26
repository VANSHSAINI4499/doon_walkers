import 'package:doon_walkers/core/motion/app_motion.dart';
import 'package:doon_walkers/core/theme/app_dimens.dart';
import 'package:doon_walkers/core/theme/app_palette.dart';
import 'package:doon_walkers/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// How much visual weight a [StatDisplay] carries.
enum StatSize {
  /// 64sp. One per screen at most — this is *the* number the screen is
  /// about.
  hero,

  /// 40sp. The primary stat on a card.
  large,

  /// 28sp. One of several stats in a row.
  medium,

  /// 20sp. An inline stat inside a list row.
  small,
}

/// A **large number with a small caption** — the focal point of a screen.
///
/// This is the shape the direction asks for: "Today / 8,432 / steps"
/// rather than "You have walked 8,432 steps today." Three slots, all
/// optional except the value:
///
/// ```
///   TODAY          ← eyebrow: what period/context this covers
///   8,432          ← value:   the number itself, the focal point
///   steps          ← label:   what it counts
/// ```
///
/// The number does the work. It is the heaviest weight and the largest
/// size in the type scale, and everything around it is deliberately
/// quiet — which is why this needs no card, no border and no colour to
/// read as important. Reach for [color] only when the value itself
/// carries meaning (a streak in Nature Green, an overdue count in red),
/// never for decoration.
///
/// ```dart
/// StatDisplay(value: '8,432', eyebrow: 'Today', label: 'steps')
/// ```
class StatDisplay extends StatelessWidget {
  const StatDisplay({
    super.key,
    required this.value,
    this.eyebrow,
    this.label,
    this.size = StatSize.large,
    this.color,
    this.unit,
    this.alignment = CrossAxisAlignment.start,
  });

  /// The number, already formatted. This widget does not format — the
  /// caller knows whether it wants `8,432`, `8.4k` or `08:32`.
  final String value;

  /// Small caps above the number: the context ("TODAY", "THIS MONTH").
  final String? eyebrow;

  /// Small caption below the number: what it counts ("steps", "treks").
  final String? label;

  final StatSize size;

  /// Tints the number only — never the eyebrow or label. Defaults to the
  /// palette's primary ink.
  final Color? color;

  /// A suffix set alongside the number at a smaller size ("km", "%").
  /// Sits on the number's baseline so the pair reads as one token.
  final String? unit;

  final CrossAxisAlignment alignment;

  TextStyle get _valueStyle => switch (size) {
    StatSize.hero => AppTextStyles.statXLarge,
    StatSize.large => AppTextStyles.statLarge,
    StatSize.medium => AppTextStyles.statMedium,
    StatSize.small => AppTextStyles.statSmall,
  };

  double get _unitSize => switch (size) {
    StatSize.hero => 24,
    StatSize.large => 18,
    StatSize.medium => 14,
    StatSize.small => 12,
  };

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final ink = color ?? palette.textPrimary;

    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow!.toUpperCase(),
            style: AppTextStyles.overline.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          // Baseline-ish: the unit sits low against a number whose line
          // box is tight, so bottom alignment reads correctly without
          // paying for a full baseline row.
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value, style: _valueStyle.copyWith(color: ink)),
            if (unit != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  unit!,
                  style: AppTextStyles.statSmall.copyWith(
                    fontSize: _unitSize,
                    color: palette.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (label != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            label!,
            style: AppTextStyles.statLabel.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// A [StatDisplay] whose number counts up when it first appears, and
/// animates between values on change.
///
/// One of the four motions the direction sanctions ("progress
/// animation"). Use it where the number is the point of the screen — a
/// streak count, a challenge total. Do **not** use it for a row of six
/// stats; six numbers spinning at once is noise, not delight.
class AnimatedStatDisplay extends StatelessWidget {
  const AnimatedStatDisplay({
    super.key,
    required this.value,
    this.format,
    this.eyebrow,
    this.label,
    this.size = StatSize.large,
    this.color,
    this.unit,
    this.duration = AppMotion.slow,
    this.alignment = CrossAxisAlignment.start,
  });

  /// The target number.
  final num value;

  /// Formats the interpolated value. Defaults to a plain integer, which
  /// is right for counts; pass a formatter for currency or decimals.
  final String Function(num)? format;

  final String? eyebrow;
  final String? label;
  final StatSize size;
  final Color? color;
  final String? unit;
  final Duration duration;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: value.toDouble()),
    duration: duration,
    curve: AppMotion.emphasized,
    builder: (context, v, _) => StatDisplay(
      value: format?.call(v) ?? v.round().toString(),
      eyebrow: eyebrow,
      label: label,
      size: size,
      color: color,
      unit: unit,
      alignment: alignment,
    ),
  );
}

/// Several [StatDisplay]s side by side, separated by hairlines.
///
/// The divider is what lets three stats share a row without needing three
/// cards — fewer boxes, same grouping. Keep it to 2–4 items; past that
/// the numbers get too small to be the focal point of anything.
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.stats, this.size = StatSize.medium});

  final List<StatDisplay> stats;

  /// Applied to every child, overriding their own [StatDisplay.size], so
  /// a row is always visually even.
  final StatSize size;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0)
              VerticalDivider(
                color: palette.border,
                thickness: 1,
                width: AppSpacing.xl,
              ),
            Expanded(
              child: StatDisplay(
                value: stats[i].value,
                eyebrow: stats[i].eyebrow,
                label: stats[i].label,
                color: stats[i].color,
                unit: stats[i].unit,
                size: size,
                alignment: CrossAxisAlignment.start,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
