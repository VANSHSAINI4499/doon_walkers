import 'dart:math' as math;
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/activity/domain/services/activity_period.dart';
import 'package:doon_walkers/features/activity/presentation/providers/activity_dashboard_providers.dart';
import 'package:doon_walkers/features/activity/presentation/widgets/activity_format.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Monthly Goal Progress Screen — pushed from Month View module.
class MonthlyGoalProgressScreen extends ConsumerWidget {
  const MonthlyGoalProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final now = DateTime.now();
    final monthPeriod = ActivityPeriod.month(now);
    final summaryAsync = ref.watch(activitySummaryProvider(monthPeriod));
    final goalAsync = ref.watch(userGoalProvider('monthly_steps'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Goal Progress'),
      ),
      body: SafeArea(
        child: summaryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error loading goal data', style: AppTextStyles.bodyMedium)),
          data: (summary) {
            final target = goalAsync.when(
              data: (data) => (data is Map && data['target_value'] != null)
                  ? (data['target_value'] as num).toInt()
                  : 200000,
              loading: () => 200000,
              error: (_, __) => 200000,
            );

            final currentSteps = summary.totalSteps;
            final fraction = (currentSteps / target).clamp(0.0, 1.0);
            final percent = (fraction * 100).round();

            final daysPassed = now.day;
            final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
            final daysRemaining = math.max(1, daysInMonth - daysPassed);
            final avgPerDay = daysPassed == 0 ? 0 : (currentSteps / daysPassed).round();
            final remainingSteps = math.max(0, target - currentSteps);
            final needPerDay = (remainingSteps / daysRemaining).round();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Step Goal Ring & Progress Bar
                  AppCard(
                    child: Column(
                      children: [
                        Center(
                          child: AppProgressRing(
                            value: fraction,
                            size: 160,
                            strokeWidth: 12,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('$percent%', style: AppTextStyles.statLarge),
                                Text('completed', style: AppTextStyles.secondary(AppTextStyles.labelSmall)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppProgressBar(
                          value: fraction,
                          label: 'Monthly Target',
                          trailing: '${ActivityFormat.stepsCompact(currentSteps)} / ${ActivityFormat.stepsCompact(target)}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Motivational Banner
                  AppCard(
                    color: palette.primarySubtle,
                    borderColor: palette.primary.withValues(alpha: 0.3),
                    child: Row(
                      children: [
                        AppIcon(AppIcons.trending, size: 24, color: palette.primary),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            percent >= 50
                                ? 'Great pace! You are over halfway to your monthly target.'
                                : 'Keep stepping! Every walk brings you closer to your goal.',
                            style: AppTextStyles.tinted(AppTextStyles.titleSmall, palette.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Weekly Progress Chart
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Weekly Progress Overview', style: AppTextStyles.titleSmall),
                        const SizedBox(height: AppSpacing.lg),
                        AspectRatio(
                          aspectRatio: 2.2,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              gridData: const FlGridData(show: false),
                              titlesData: const FlTitlesData(show: false),
                              borderData: FlBorderData(show: false),
                              barGroups: [
                                for (var i = 0; i < 4; i++)
                                  BarChartGroupData(
                                    x: i,
                                    barRods: [
                                      BarChartRodData(
                                        toY: (currentSteps / 4).toDouble(),
                                        color: palette.primary,
                                        width: 20,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Goal Details Table
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Goal Details', style: AppTextStyles.titleSmall),
                        const SizedBox(height: AppSpacing.md),
                        _DetailRow(label: 'Goal Type', value: 'Monthly Steps'),
                        _DetailRow(label: 'Monthly Goal', value: ActivityFormat.steps(target)),
                        _DetailRow(label: 'Daily Average', value: ActivityFormat.steps(avgPerDay)),
                        _DetailRow(label: 'Days Passed', value: '$daysPassed / $daysInMonth'),
                        _DetailRow(label: 'Days Remaining', value: '$daysRemaining'),
                        _DetailRow(label: 'Needed per Day', value: ActivityFormat.steps(needPerDay), highlight: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Milestones Track
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Milestones Track', style: AppTextStyles.titleSmall),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _MilestoneChip(label: '50K', reached: currentSteps >= 50000),
                            _MilestoneChip(label: '100K', reached: currentSteps >= 100000),
                            _MilestoneChip(label: '150K', reached: currentSteps >= 150000),
                            _MilestoneChip(label: '200K', reached: currentSteps >= 200000),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Tips to Reach Goal
                  AppCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppIcon(AppIcons.info, size: 20, color: palette.primary),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Tips to Reach Your Goal', style: AppTextStyles.titleSmall),
                              const SizedBox(height: 4),
                              Text(
                                'A 15-minute brisk walk after meals adds ~1,500 steps to your daily total effortlessly!',
                                style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.secondary(AppTextStyles.bodyMedium)),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: highlight ? palette.primary : palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneChip extends StatelessWidget {
  const _MilestoneChip({required this.label, required this.reached});

  final String label;
  final bool reached;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: reached ? palette.primary : palette.cardHigh,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: reached ? palette.onPrimary : palette.textSecondary,
        ),
      ),
    );
  }
}
