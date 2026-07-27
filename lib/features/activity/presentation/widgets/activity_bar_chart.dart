import 'package:doon_walkers/core/design_system.dart';
import 'package:flutter/material.dart';

/// One bar in an [ActivityBarChart].
class ActivityBar {
  const ActivityBar({
    required this.label,
    required this.value,
    this.highlight = false,
    this.emphasise = false,
  });

  /// Short axis label (a weekday initial, a day number, "W1").
  final String label;

  final int value;

  /// The best bar in the set — drawn in the accent.
  final bool highlight;

  /// The bar representing "now" (today, the current week). Drawn with a
  /// ring rather than a fill so it can coexist with [highlight] on the
  /// same bar without one colour overriding the other.
  final bool emphasise;
}

/// A hand-rolled bar chart — flex layout, no charting dependency.
///
/// ## Why not fl_chart
///
/// Everything drawn here is a rectangle with a rounded top, laid out
/// evenly across the available width. That is `Row` + `Expanded` +
/// fractional heights. Pulling in a charting package would add a sizeable
/// dependency plus its own axis/legend/theming model to fight against the
/// calm palette, to draw shapes Flutter already draws. The one genuinely
/// curved thing in the design system (the progress ring) is the one place
/// that uses `CustomPaint`.
///
/// ## Scaling
///
/// Bars scale against the largest value in the set, not against the goal —
/// so a week where every day missed the goal still shows shape and
/// relative difference rather than five identically-stubby bars. When
/// [goal] is supplied it is drawn as a dashed reference line instead,
/// which is the honest way to show "this is the target" without distorting
/// the bars.
///
/// An all-zero set renders flat bars at [_minBarFraction] rather than
/// nothing, so the axis labels still line up under something.
class ActivityBarChart extends StatelessWidget {
  const ActivityBarChart({
    super.key,
    required this.bars,
    this.height = 140,
    this.goal,
    this.showValues = false,
  });

  final List<ActivityBar> bars;

  /// Height of the plot area, excluding the labels below it.
  final double height;

  /// Optional per-bar target, drawn as a reference line.
  final int? goal;

  /// Print each bar's value above it. Only legible with few bars — the
  /// Week view uses it, the Month view (28–31 bars) does not.
  final bool showValues;

  /// Bars never render at literally zero height, or the chart would look
  /// broken rather than empty.
  static const double _minBarFraction = 0.02;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    if (bars.isEmpty) return const SizedBox.shrink();

    final maxValue = bars.fold<int>(0, (m, b) => b.value > m ? b.value : m);
    // The reference line has to fit inside the plot too, so it joins the
    // scale — otherwise a goal above every bar would be drawn off the top.
    final scale = [
      maxValue,
      if (goal != null) goal!,
    ].fold<int>(0, (m, v) => v > m ? v : m);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: Stack(
            children: [
              if (goal != null && scale > 0)
                _GoalLine(
                  fraction: (goal! / scale).clamp(0.0, 1.0),
                  palette: palette,
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final bar in bars)
                    Expanded(
                      child: _Bar(
                        bar: bar,
                        fraction:
                            scale <= 0
                                ? _minBarFraction
                                : (bar.value / scale).clamp(
                                  _minBarFraction,
                                  1.0,
                                ),
                        palette: palette,
                        showValue: showValues,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (final bar in bars)
              Expanded(
                child: Text(
                  bar.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: AppTextStyles.labelSmall.copyWith(
                    color:
                        bar.emphasise
                            ? palette.textPrimary
                            : palette.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.bar,
    required this.fraction,
    required this.palette,
    required this.showValue,
  });

  final ActivityBar bar;
  final double fraction;
  final AppPalette palette;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    final fill = bar.highlight ? palette.primary : palette.cardHigh;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (showValue)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                bar.value == 0 ? '' : _short(bar.value),
                maxLines: 1,
                style: AppTextStyles.labelSmall.copyWith(
                  fontSize: 9,
                  color: palette.textSecondary,
                ),
              ),
            ),
          // Animates up from the baseline — one of the four sanctioned
          // motions ("progress animation"). One tween for the whole
          // column, so the bars rise together rather than staggering.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fraction),
            duration: AppMotion.slow,
            curve: AppMotion.emphasized,
            builder:
                (context, value, _) => FractionallySizedBox(
                  heightFactor: value.clamp(0.0, 1.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                      border:
                          bar.emphasise
                              ? Border.all(color: palette.primary, width: 1.5)
                              : null,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  /// 8,432 → "8.4k". Bars are narrow; a full number would not fit.
  static String _short(int value) {
    if (value < 1000) return '$value';
    final k = value / 1000;
    return k >= 10 ? '${k.round()}k' : '${k.toStringAsFixed(1)}k';
  }
}

/// The goal reference line — a hairline with a small label.
class _GoalLine extends StatelessWidget {
  const _GoalLine({required this.fraction, required this.palette});

  final double fraction;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: FractionallySizedBox(
        heightFactor: fraction,
        widthFactor: 1,
        child: Align(
          alignment: Alignment.topLeft,
          child: Container(
            height: 1,
            decoration: BoxDecoration(color: palette.borderStrong),
          ),
        ),
      ),
    );
  }
}
