import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/profile/domain/entities/points_ledger_entry.dart';
import 'package:doon_walkers/features/profile/domain/points_reason_labels.dart';
import 'package:doon_walkers/features/profile/domain/services/points_history_grouping.dart';
import 'package:flutter/material.dart';

/// One row in Points History — reason label, relative time, and the
/// signed point amount. [PointsReasonLabels] is the only place a machine
/// `reason` string becomes screen copy.
class PointsLedgerTile extends StatelessWidget {
  const PointsLedgerTile({super.key, required this.entry, this.now});

  final PointsLedgerEntry entry;

  /// Injectable for tests; defaults to the wall clock.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    // The calm palette has one accent (see StreakSection's doc) — a
    // positive award uses it, same as everywhere else "this is good"
    // is signalled. Negative entries (none exist yet, but the column is
    // signed) use the one other semantic colour the palette defines.
    final isPositive = entry.points >= 0;
    final amountColor = isPositive ? palette.primary : palette.danger;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color:
                  isPositive ? palette.primarySubtle : palette.dangerContainer,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: AppIcon(
              isPositive ? AppIcons.trending : AppIcons.trendingDown,
              size: 18,
              color: amountColor,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  PointsReasonLabels.labelFor(entry.reason),
                  style: AppTextStyles.titleSmall.copyWith(
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatPointsHistoryTime(entry.createdAt, now: now),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${isPositive ? '+' : ''}${entry.points}',
            style: AppTextStyles.titleMedium.copyWith(
              color: amountColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
