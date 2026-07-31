import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/activity/presentation/providers/activity_dashboard_providers.dart';
import 'package:doon_walkers/features/celebrations/presentation/widgets/weekly_streak_calendar.dart';
import 'package:doon_walkers/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The daily activity streak's own destination — reached from the
/// streak celebration's "View Streak Details" button and from the
/// home screen's [StreakBadge] (Part 4). Reads
/// [myActivityStreakProvider] directly rather than duplicating it, so
/// this always agrees with the badge and the celebration.
///
/// Distinct from [StreakSection] on Profile, which is the unrelated
/// trekking-attendance streak (consecutive MONTHS with an attended
/// trek) — see that class's own doc for why the two are kept apart.
class StreakDetailsScreen extends ConsumerWidget {
  const StreakDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final streakAsync = ref.watch(myActivityStreakProvider);
    final trailingWeekAsync = ref.watch(trailingWeekProvider(DateTime.now()));

    return Scaffold(
      appBar: AppBar(title: const Text('Streak Details')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: palette.primarySubtle,
                        shape: BoxShape.circle,
                      ),
                      child: AnimatedStreakFlame(
                        icon: AppIcons.streak,
                        color: palette.primary,
                        size: 64,
                        isActive: (streakAsync.valueOrNull ?? 0) > 0,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    streakAsync.when(
                      data:
                          (streak) => Text(
                            '$streak',
                            style: AppTextStyles.statXLarge.copyWith(
                              color: palette.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      loading:
                          () => const Shimmer(
                            child: SkeletonBox(
                              width: 60,
                              height: 48,
                              borderRadius: AppRadius.sm,
                            ),
                          ),
                      error:
                          (_, __) => Text(
                            '—',
                            style: AppTextStyles.statXLarge.copyWith(
                              color: palette.textDisabled,
                            ),
                          ),
                    ),
                    Text(
                      'Day Streak',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'This Week',
                style: AppTextStyles.titleSmall.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: trailingWeekAsync.when(
                  data: (days) => WeeklyStreakCalendar(days: days),
                  loading:
                      () => const Shimmer(
                        child: SkeletonBox(
                          height: 56,
                          borderRadius: AppRadius.sm,
                        ),
                      ),
                  error:
                      (_, __) => Text(
                        "Could not load this week's activity.",
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: palette.danger,
                        ),
                      ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppIcon(AppIcons.info, size: 18, color: palette.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Your streak counts consecutive days with recorded '
                        'activity. Sync your steps daily to keep it alive — '
                        "missing a full day (or yesterday, if it's still "
                        'early) breaks it.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
