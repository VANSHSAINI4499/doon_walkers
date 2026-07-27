import 'dart:math' as math;
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/activity/domain/entities/daily_activity.dart';
import 'package:doon_walkers/features/activity/domain/entities/user_achievement.dart';
import 'package:doon_walkers/features/activity/presentation/providers/activity_dashboard_providers.dart';
import 'package:doon_walkers/features/activity/presentation/widgets/activity_format.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Activity Insights Screen — pushed from Insights teaser cards or App Bar.
class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1);
    if (_selectedMonth.isBefore(thisMonth)) {
      setState(() {
        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
      });
    }
  }

  void _showPercentileInfoModal(BuildContext context) {
    final palette = AppPalette.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text('How Percentiles Work', style: AppTextStyles.titleMedium),
        content: Text(
          'Your percentile shows the percentage of active community members whose step count you exceeded during the selected month.\n\nA floor of 5 active tracking members is required for percentile calculations to protect community privacy.',
          style: AppTextStyles.bodyMedium.copyWith(color: palette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Got it', style: AppTextStyles.labelLarge.copyWith(color: palette.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final percentileAsync = ref.watch(activityPercentileProvider(_selectedMonth));
    final comparisonAsync = ref.watch(monthComparisonProvider(_selectedMonth));
    final bestDayAsync = ref.watch(bestDayProvider(_selectedMonth));
    final activeDaysAsync = ref.watch(activeDaysProvider(_selectedMonth));
    final achievementsAsync = ref.watch(userAchievementsProvider);

    final monthLabel = '${ActivityFormat.monthShort(_selectedMonth)} ${_selectedMonth.year}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Insights'),
        actions: [
          IconButton(
            icon: const AppIcon(AppIcons.info),
            tooltip: 'Percentile Info',
            onPressed: () => _showPercentileInfoModal(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Your Overview Banner
              _OverviewBanner(
                monthLabel: monthLabel,
                percentileAsync: percentileAsync,
                onPreviousMonth: _previousMonth,
                onNextMonth: _nextMonth,
                canGoNext: _selectedMonth.isBefore(DateTime(DateTime.now().year, DateTime.now().month, 1)),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Key Highlights Grid (4 tiles)
              comparisonAsync.when(
                data: (comp) => _KeyHighlightsGrid(comparison: comp),
                loading: () => const SkeletonBox(height: 160),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Activity Comparison Chart
              comparisonAsync.when(
                data: (comp) => _ActivityComparisonChart(comparison: comp),
                loading: () => const SkeletonBox(height: 180),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Best Day Card & Consistency Ring Row
              Row(
                children: [
                  Expanded(
                    child: bestDayAsync.when(
                      data: (best) => _BestDayCard(bestDay: best),
                      loading: () => const SkeletonBox(height: 140),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: activeDaysAsync.when(
                      data: (count) => _ConsistencyCard(
                        activeDays: count,
                        daysInMonth: DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day,
                      ),
                      loading: () => const SkeletonBox(height: 140),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Recent Achievements Grid
              achievementsAsync.when(
                data: (list) => _RecentAchievementsSection(achievements: list),
                loading: () => const SkeletonBox(height: 120),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Tips for You card
              const _TipsCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewBanner extends StatelessWidget {
  const _OverviewBanner({
    required this.monthLabel,
    required this.percentileAsync,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.canGoNext,
  });

  final String monthLabel;
  final AsyncValue<int?> percentileAsync;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final bool canGoNext;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return AppCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const AppIcon(AppIcons.back, size: 18),
                onPressed: onPreviousMonth,
              ),
              Text(monthLabel, style: AppTextStyles.titleMedium),
              IconButton(
                icon: AppIcon(
                  AppIcons.forward,
                  size: 18,
                  color: canGoNext ? palette.textPrimary : palette.textDisabled,
                ),
                onPressed: canGoNext ? onNextMonth : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          percentileAsync.when(
            data: (pct) => Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: palette.primarySubtle,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: palette.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(AppIcons.medal, size: 24, color: palette.primary),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    pct != null ? 'Top $pct% of Doon Walkers' : 'Keep walking to earn percentile ranking',
                    style: AppTextStyles.tinted(AppTextStyles.titleSmall, palette.primary),
                  ),
                ],
              ),
            ),
            loading: () => const SkeletonBox(height: 48),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _KeyHighlightsGrid extends StatelessWidget {
  const _KeyHighlightsGrid({required this.comparison});

  final Map<String, double> comparison;

  @override
  Widget build(BuildContext context) {
    final curSteps = comparison['current_steps'] ?? 0;
    final priSteps = comparison['prior_steps'] ?? 0;
    final stepsDelta = priSteps > 0 ? ((curSteps - priSteps) / priSteps * 100).round() : null;

    final curCal = comparison['current_cal'] ?? 0;
    final priCal = comparison['prior_cal'] ?? 0;
    final calDelta = priCal > 0 ? ((curCal - priCal) / priCal * 100).round() : null;

    final curDist = comparison['current_dist'] ?? 0;
    final priDist = comparison['prior_dist'] ?? 0;
    final distDelta = priDist > 0 ? ((curDist - priDist) / priDist * 100).round() : null;

    final curAct = comparison['current_active'] ?? 0;
    final priAct = comparison['prior_active'] ?? 0;
    final actDelta = priAct > 0 ? ((curAct - priAct) / priAct * 100).round() : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Key Highlights', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _HighlightTile(
                icon: AppIcons.steps,
                title: ActivityFormat.steps(curSteps.round()),
                label: 'steps',
                delta: stepsDelta,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _HighlightTile(
                icon: AppIcons.calories,
                title: ActivityFormat.calories(curCal),
                label: 'burned',
                delta: calDelta,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _HighlightTile(
                icon: AppIcons.distance,
                title: ActivityFormat.distance(curDist),
                label: 'distance',
                delta: distDelta,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _HighlightTile(
                icon: AppIcons.duration,
                title: '${curAct.round()} mins',
                label: 'active time',
                delta: actDelta,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HighlightTile extends StatelessWidget {
  const _HighlightTile({
    required this.icon,
    required this.title,
    required this.label,
    this.delta,
  });

  final IconData icon;
  final String title;
  final String label;
  final int? delta;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppIcon(icon, size: 18, color: palette.textSecondary),
              if (delta != null)
                Text(
                  ActivityFormat.delta(delta!),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: delta! >= 0 ? palette.primary : palette.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: AppTextStyles.titleMedium),
          Text(label, style: AppTextStyles.secondary(AppTextStyles.labelSmall)),
        ],
      ),
    );
  }
}

class _ActivityComparisonChart extends StatelessWidget {
  const _ActivityComparisonChart({required this.comparison});

  final Map<String, double> comparison;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final curSteps = comparison['current_steps'] ?? 0;
    final priSteps = comparison['prior_steps'] ?? 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Activity Comparison', style: AppTextStyles.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Current Month vs Prior Month Step Breakdown',
            style: AppTextStyles.secondary(AppTextStyles.bodySmall),
          ),
          const SizedBox(height: AppSpacing.lg),
          AspectRatio(
            aspectRatio: 2.0,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(toY: priSteps / 4, color: palette.textDisabled, width: 14, borderRadius: BorderRadius.circular(4)),
                      BarChartRodData(toY: curSteps / 4, color: palette.primary, width: 14, borderRadius: BorderRadius.circular(4)),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(toY: priSteps / 4 * 1.1, color: palette.textDisabled, width: 14, borderRadius: BorderRadius.circular(4)),
                      BarChartRodData(toY: curSteps / 4 * 0.9, color: palette.primary, width: 14, borderRadius: BorderRadius.circular(4)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(color: palette.primary, label: 'Current Month'),
              const SizedBox(width: AppSpacing.xl),
              _LegendItem(color: palette.textDisabled, label: 'Prior Month'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: AppTextStyles.secondary(AppTextStyles.labelSmall)),
      ],
    );
  }
}

class _BestDayCard extends StatelessWidget {
  const _BestDayCard({required this.bestDay});

  final DailyActivity? bestDay;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final dayStr = bestDay != null ? '${bestDay!.date.day} ${ActivityFormat.monthShort(bestDay!.date)}' : '—';
    final stepsStr = bestDay != null ? ActivityFormat.steps(bestDay!.steps) : 'No data';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(AppIcons.star, size: 18, color: palette.primary),
              const SizedBox(width: AppSpacing.xs),
              Text('Best Day', style: AppTextStyles.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(stepsStr, style: AppTextStyles.statMedium),
          const SizedBox(height: 2),
          Text(dayStr, style: AppTextStyles.secondary(AppTextStyles.labelSmall)),
        ],
      ),
    );
  }
}

class _ConsistencyCard extends StatelessWidget {
  const _ConsistencyCard({required this.activeDays, required this.daysInMonth});

  final int activeDays;
  final int daysInMonth;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final targetDays = math.min(20, daysInMonth);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(AppIcons.streak, size: 18, color: palette.primary),
              const SizedBox(width: AppSpacing.xs),
              Text('Consistency', style: AppTextStyles.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('$activeDays / $targetDays days', style: AppTextStyles.statMedium),
          const SizedBox(height: 2),
          Text('Goal: 20 active days', style: AppTextStyles.secondary(AppTextStyles.labelSmall)),
        ],
      ),
    );
  }
}

class _RecentAchievementsSection extends StatelessWidget {
  const _RecentAchievementsSection({required this.achievements});

  final List<UserAchievement> achievements;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    if (achievements.isEmpty) {
      return AppCard(
        child: Column(
          children: [
            AppIcon(AppIcons.medal, size: 28, color: palette.textDisabled),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No achievements unlocked yet',
              style: AppTextStyles.titleSmall,
            ),
            const SizedBox(height: 2),
            Text(
              'Keep tracking steps and completing treks to earn badges!',
              style: AppTextStyles.secondary(AppTextStyles.bodySmall),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Unlocked Achievements', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (final item in achievements.take(3))
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      children: [
                        AppIcon(AppIcons.medal, size: 24, color: palette.primary),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          item.title,
                          style: AppTextStyles.labelSmall,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}


class _TipsCard extends StatelessWidget {
  const _TipsCard();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return AppCard(
      borderColor: palette.primary.withValues(alpha: 0.3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(AppIcons.explore, size: 22, color: palette.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tips for You', style: AppTextStyles.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'Consistency is key! Aim for 30 minutes of active walking per day to build long-term cardiovascular health.',
                  style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
