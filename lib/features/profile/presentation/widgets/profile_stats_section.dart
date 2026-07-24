import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/registrations/domain/entities/registration_stats.dart';
import 'package:doon_walkers/features/registrations/presentation/providers/registration_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Four Profile stat tiles sourced from [myRegistrationStatsProvider],
/// laid out 2x2. Redesign Phase 5 restyles them as glass stat tiles with
/// the bold stat numeral type, consistent with the Challenges tiles — the
/// data (registered / attended / upcoming / cancelled) is unchanged.
class ProfileStatsSection extends ConsumerWidget {
  const ProfileStatsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(myRegistrationStatsProvider);

    return statsAsync.when(
      loading: () => const Column(
        children: [
          SkeletonStatRow(count: 2),
          SizedBox(height: AppSpacing.md),
          SkeletonStatRow(count: 2),
        ],
      ),
      error: (error, stack) {
        debugPrint('ProfileStatsSection: failed to load stats: $error');
        return Text(
          'Stats unavailable right now.',
          style: AppTextStyles.secondary(AppTextStyles.bodySmall),
          textAlign: TextAlign.center,
        );
      },
      data: (stats) => _StatsGrid(stats: stats),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final RegistrationStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatTile(
                  icon: AppIcons.ticket,
                  value: stats.totalRegistered,
                  label: 'Total Treks Registered',
                  accent: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _StatTile(
                  icon: AppIcons.hiking,
                  value: stats.totalAttended,
                  label: 'Total Treks Attended',
                  accent: AppColors.secondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatTile(
                  icon: AppIcons.eventAvailable,
                  value: stats.upcoming,
                  label: 'Upcoming Treks',
                  accent: AppColors.accent,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _StatTile(
                  icon: AppIcons.eventBusy,
                  value: stats.cancelled,
                  label: 'Cancelled Registrations',
                  accent: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.value, required this.label, required this.accent});

  final IconData icon;
  final int value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blurEnabled: false,
      glowColor: accent,
      glowOpacity: 0.12,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, color: accent, size: 24),
          const SizedBox(height: AppSpacing.sm),
          Text('$value', style: AppTextStyles.tinted(AppTextStyles.statMedium, accent)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTextStyles.statLabel,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
