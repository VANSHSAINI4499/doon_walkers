import 'package:doon_walkers/core/motion/app_motion.dart';
import 'package:doon_walkers/core/motion/pressable.dart';
import 'package:doon_walkers/core/theme/app_dimens.dart';
import 'package:doon_walkers/core/theme/app_palette.dart';
import 'package:doon_walkers/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// A calm segmented control — a recessed track with one raised, filled
/// segment marking the selection.
///
/// Used where a screen has two-to-four mutually exclusive *views of the
/// same thing* (Challenges' My/Explore split; Activity's Day/Week/Month).
/// That is a different job from tabs, which navigate between different
/// things, and from filter chips, which are independently toggleable —
/// this is one choice, always exactly one selected.
///
/// Lives in `core/widgets` rather than in a feature because two phases
/// need it and a second copy would drift. Keep it to short labels: the
/// segments split the available width evenly, so a long label in one
/// segment shrinks every other.
///
/// The selection is animated (a fill crossfade, not a sliding thumb) —
/// the calm direction's "meaningful only" motion budget covers a state
/// change of this size, and a sliding indicator across an evenly-divided
/// track adds a moving part for no added clarity.
class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  }) : assert(segments.length >= 2, 'A single segment is not a choice.');

  /// Ordered `(value, label)` pairs, left to right.
  final List<(T, String)> segments;

  /// The currently-selected value. Should be one of [segments]' values; if
  /// it is not, nothing renders as selected (rather than throwing) — a
  /// caller mid-migration should look wrong, not crash.
  final T value;

  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.cardHigh,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          for (final (segmentValue, label) in segments)
            Expanded(
              child: _Segment(
                label: label,
                selected: segmentValue == value,
                onTap: () {
                  if (segmentValue != value) onChanged(segmentValue);
                },
                palette: palette,
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.palette,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Pressable(
        onTap: onTap,
        // Barely any press-scale: the segments sit flush against each
        // other, so a 4% shrink would show a gap opening up.
        scale: AppMotion.pressScaleLarge,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? palette.card : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          child: AnimatedDefaultTextStyle(
            duration: AppMotion.fast,
            style: AppTextStyles.labelMedium.copyWith(
              color: selected ? palette.textPrimary : palette.textSecondary,
            ),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ),
    );
  }
}
