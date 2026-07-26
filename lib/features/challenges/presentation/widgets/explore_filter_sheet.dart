import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/challenges/domain/services/challenge_search.dart';
import 'package:flutter/material.dart';

/// Result of [showExploreFilterSheet] — null metric set means "no metric
/// filter" (matches everything); null duration means "no duration
/// filter" (the slider was left at its full extent).
class ExploreFilterResult {
  const ExploreFilterResult({required this.metrics, required this.duration});

  final Set<ChallengeMetricFilter> metrics;
  final ChallengeDurationRange? duration;

  bool get isEmpty => metrics.isEmpty && duration == null;
}

/// The Explore filter sheet — Phase 24. Did not exist before this phase;
/// Phase 23's audit found only inline always-visible metric chips, no
/// bottom sheet and no duration filter of any kind.
///
/// Combines what already existed (metric chips, via
/// [ChallengeMetricFilter]) with what didn't (a duration-in-days range
/// slider) into one sheet reached from a filter icon, replacing the
/// always-on chip row so there is one clear place filters live.
Future<ExploreFilterResult?> showExploreFilterSheet(
  BuildContext context, {
  required Set<ChallengeMetricFilter> initialMetrics,
  required ChallengeDurationRange? initialDuration,
}) {
  return showModalBottomSheet<ExploreFilterResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ExploreFilterSheet(
      initialMetrics: initialMetrics,
      initialDuration: initialDuration,
    ),
  );
}

/// The full slider extent. A challenge whose derived duration has no
/// real value (`allTime`, or a `customRange` missing a date) always
/// passes the filter regardless of where the handles sit — see
/// `filterChallenges`'s `durationRange` doc.
const int _minDurationDays = 1;
const int _maxDurationDays = 90;

class _ExploreFilterSheet extends StatefulWidget {
  const _ExploreFilterSheet({
    required this.initialMetrics,
    required this.initialDuration,
  });

  final Set<ChallengeMetricFilter> initialMetrics;
  final ChallengeDurationRange? initialDuration;

  @override
  State<_ExploreFilterSheet> createState() => _ExploreFilterSheetState();
}

class _ExploreFilterSheetState extends State<_ExploreFilterSheet> {
  late Set<ChallengeMetricFilter> _metrics = {...widget.initialMetrics};
  late RangeValues _duration = widget.initialDuration == null
      ? RangeValues(
          _minDurationDays.toDouble(),
          _maxDurationDays.toDouble(),
        )
      : RangeValues(
          widget.initialDuration!.minDays.toDouble(),
          widget.initialDuration!.maxDays.toDouble(),
        );

  bool get _isFullRange =>
      _duration.start <= _minDurationDays && _duration.end >= _maxDurationDays;

  void _toggleMetric(ChallengeMetricFilter filter) {
    setState(() {
      if (!_metrics.remove(filter)) _metrics.add(filter);
    });
  }

  void _clearAll() {
    setState(() {
      _metrics = {};
      _duration = RangeValues(
        _minDurationDays.toDouble(),
        _maxDurationDays.toDouble(),
      );
    });
  }

  void _apply() {
    Navigator.of(context).pop(
      ExploreFilterResult(
        metrics: _metrics,
        duration: _isFullRange
            ? null
            : ChallengeDurationRange(
                minDays: _duration.start.round(),
                maxDays: _duration.end.round(),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xl + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: palette.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Filter challenges',
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                ),
                TextButton(onPressed: _clearAll, child: const Text('Clear all')),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'What it measures',
              style: AppTextStyles.titleSmall.copyWith(color: palette.textPrimary),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final filter in ChallengeMetricFilter.values)
                  _FilterChip(
                    label: filter.label,
                    selected: _metrics.contains(filter),
                    onTap: () => _toggleMetric(filter),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Duration',
              style: AppTextStyles.titleSmall.copyWith(color: palette.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              _isFullRange
                  ? 'Any length (challenges with no fixed length always match)'
                  : '${_duration.start.round()}–${_duration.end.round()} days',
              style: AppTextStyles.bodySmall.copyWith(color: palette.textSecondary),
            ),
            RangeSlider(
              values: _duration,
              min: _minDurationDays.toDouble(),
              max: _maxDurationDays.toDouble(),
              divisions: _maxDurationDays - _minDurationDays,
              activeColor: palette.primary,
              inactiveColor: palette.border,
              labels: RangeLabels(
                '${_duration.start.round()}d',
                '${_duration.end.round()}d',
              ),
              onChanged: (value) => setState(() => _duration = value),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Show results',
              variant: AppButtonVariant.primary,
              fullWidth: true,
              onPressed: _apply,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? palette.primarySubtle : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: selected ? palette.primary : palette.border),
          ),
          child: Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: selected ? palette.primary : palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
