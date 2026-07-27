import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/activity/domain/services/activity_period.dart';
import 'package:doon_walkers/features/activity/presentation/providers/activity_dashboard_providers.dart';
import 'package:doon_walkers/features/activity/presentation/widgets/activity_format.dart';
import 'package:doon_walkers/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:doon_walkers/features/registrations/presentation/providers/registration_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The member's own numbers — treks attended, steps this month, tiers
/// earned — plus a secondary row of registration counts.
///
/// ## Every figure here is real
///
/// The Profile reference showed an "Events" stat and a Recent Achievements
/// strip ("Mountain Explorer" and friends). Neither exists: there is no
/// events concept, and those badge names match neither the real loyalty
/// ladder (attendance-derived, see [LoyaltyBadgeSection]) nor per-challenge
/// tier history. Both are omitted rather than filled with mismatched data.
///
/// What is shown:
///
///  - **Treks attended** — `myRegistrationStatsProvider.totalAttended`,
///    the check-in-verified count.
///  - **Steps this month** — the current month's total from Phase 11's
///    `activitySummaryProvider`. Deliberately *this month* rather than an
///    all-time "total steps": an all-time figure would need an unbounded
///    query, and the honest label is the one that matches the window it
///    actually sums.
///  - **Tiers earned** — the length of `myTierHistoryProvider`, which is
///    real earned (challenge, tier) pairs.
class ProfileStatsSection extends ConsumerWidget {
  const ProfileStatsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final statsAsync = ref.watch(myRegistrationStatsProvider);

    return statsAsync.when(
      loading: () => const AppCard(child: SkeletonStatRow()),
      error: (error, stack) {
        debugPrint('ProfileStatsSection: failed to load stats: $error');
        return AppCard(
          child: Text(
            'Stats unavailable right now.',
            style: AppTextStyles.bodySmall.copyWith(
              color: palette.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        );
      },
      data: (stats) {
        final monthSteps =
            ref
                .watch(
                  activitySummaryProvider(ActivityPeriod.month(DateTime.now())),
                )
                .valueOrNull
                ?.totalSteps;
        final tiers = ref.watch(myTierHistoryProvider).valueOrNull?.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: StatRow(
                stats: [
                  StatDisplay(
                    value: '${stats.totalAttended}',
                    label: 'treks attended',
                  ),
                  StatDisplay(
                    // An em dash while loading, never a 0 that then jumps —
                    // "0 steps" and "still loading" look identical
                    // otherwise.
                    value:
                        monthSteps == null
                            ? '—'
                            : ActivityFormat.stepsCompact(monthSteps),
                    label: 'steps this month',
                  ),
                  StatDisplay(
                    value: tiers == null ? '—' : '$tiers',
                    label: tiers == 1 ? 'tier earned' : 'tiers earned',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Column(
                children: [
                  _CountRow(
                    icon: AppIcons.ticket,
                    label: 'Treks registered',
                    value: stats.totalRegistered,
                  ),
                  Divider(height: AppSpacing.lg, color: palette.border),
                  _CountRow(
                    icon: AppIcons.eventAvailable,
                    label: 'Upcoming',
                    value: stats.upcoming,
                  ),
                  Divider(height: AppSpacing.lg, color: palette.border),
                  _CountRow(
                    icon: AppIcons.eventBusy,
                    label: 'Cancelled',
                    value: stats.cancelled,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Row(
      children: [
        AppIcon(icon, size: 18, color: palette.textSecondary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ),
        Text(
          '$value',
          style: AppTextStyles.titleSmall.copyWith(color: palette.textPrimary),
        ),
      ],
    );
  }
}
