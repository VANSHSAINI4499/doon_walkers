import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/activity/domain/services/activity_period.dart';
import 'package:doon_walkers/features/activity/presentation/widgets/activity_format.dart';
import 'package:flutter/material.dart';

/// Chevron-label-chevron header for stepping through periods.
///
/// The forward chevron is **disabled on the current period** rather than
/// hidden: hiding it would make the row jump between two and three items
/// as you navigate. There is nothing to show in the future, so paging
/// there would only ever produce an empty state the user did not ask for.
class ActivityPeriodNavigator extends StatelessWidget {
  const ActivityPeriodNavigator({
    super.key,
    required this.period,
    required this.onChanged,
    this.now,
  });

  final ActivityPeriod period;
  final ValueChanged<ActivityPeriod> onChanged;

  /// Injectable for tests; defaults to the wall clock.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final today = now ?? DateTime.now();
    final canGoForward = !period.isCurrent(today) && !period.next.isFuture(today);

    return Row(
      children: [
        _NavButton(
          icon: AppIcons.back,
          tooltip: 'Previous ${period.granularity.label.toLowerCase()}',
          onTap: () => onChanged(period.previous),
          palette: palette,
        ),
        Expanded(
          child: Text(
            ActivityFormat.periodLabel(period, now: today),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.titleMedium.copyWith(
              color: palette.textPrimary,
            ),
          ),
        ),
        _NavButton(
          icon: AppIcons.forward,
          tooltip: 'Next ${period.granularity.label.toLowerCase()}',
          onTap: canGoForward ? () => onChanged(period.next) : null,
          palette: palette,
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.palette,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return IconButton(
      icon: AppIcon(
        icon,
        size: 20,
        color: enabled ? palette.textPrimary : palette.textDisabled,
      ),
      tooltip: enabled ? tooltip : null,
      onPressed: onTap,
    );
  }
}
