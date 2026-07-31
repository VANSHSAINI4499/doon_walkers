import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/activity/domain/entities/daily_activity.dart';
import 'package:flutter/material.dart';

/// A 7-circle strip for the trailing week ending today — used by both
/// the streak celebration and Streak Details. Fed directly from
/// [trailingWeekProvider], already invalidated after every successful
/// sync, so this needs no data fetch of its own.
///
/// Iterates the actual last 7 calendar days rather than trusting
/// [days]' order/completeness — a day with nothing synced is simply
/// absent from that list (see [DailyActivity]'s own doc), and should
/// render as "no activity", not be silently skipped and throw the
/// strip out of alignment.
class WeeklyStreakCalendar extends StatelessWidget {
  const WeeklyStreakCalendar({super.key, required this.days});

  final List<DailyActivity> days;

  static const _weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final start = todayDate.subtract(const Duration(days: 6));

    final stepsByDate = <DateTime, int>{
      for (final d in days) DateTime(d.date.year, d.date.month, d.date.day): d.steps,
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final date = start.add(Duration(days: i));
        final active = (stepsByDate[date] ?? 0) > 0;
        final isToday = date == todayDate;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _weekdayLetters[date.weekday - 1],
              style: AppTextStyles.labelSmall.copyWith(
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? palette.primary : Colors.transparent,
                border: Border.all(
                  color: isToday ? palette.primary : palette.border,
                  width: isToday ? 2 : 1,
                ),
              ),
              child:
                  active
                      ? AppIcon(
                        AppIcons.streak,
                        size: 16,
                        color: palette.onPrimary,
                      )
                      : null,
            ),
          ],
        );
      }),
    );
  }
}
