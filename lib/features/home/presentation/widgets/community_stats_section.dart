import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/home/domain/entities/community_stats.dart';
import 'package:doon_walkers/features/home/presentation/providers/community_stats_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Three aggregate stat tiles (members / treks / registrations) sourced
/// from `get_community_stats()` via [communityStatsProvider].
///
/// Data behaviour is unchanged from before: a fetch failure renders the
/// same tiles zeroed-out with a small "unavailable" caption rather than a
/// hard error box — this is decorative content on a public landing
/// screen, and the real error still lives in the [AsyncValue] for anyone
/// inspecting state, just softened visually.
///
/// Visually it now uses the Phase 1 system: glass tiles, the bold stat
/// numeral type, per-tile brand glows, a count-up on the numbers, and a
/// skeleton (not a spinner) while loading.
class CommunityStatsSection extends ConsumerWidget {
  const CommunityStatsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(communityStatsProvider);

    return statsAsync.when(
      loading: () => const SkeletonStatRow(),
      error: (error, stack) => const _StatsRow(
        stats: CommunityStats.zero,
        notice: 'Stats unavailable right now.',
      ),
      data: (stats) => _StatsRow(stats: stats),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats, this.notice});

  final CommunityStats stats;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    // Zeroed error state shouldn't animate a count-up from 0 to 0.
    final animate = notice == null;

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatTile(
                  icon: AppIcons.group,
                  value: stats.memberCount,
                  label: 'Members',
                  accent: AppColors.primary,
                  animate: animate,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _StatTile(
                  icon: AppIcons.treks,
                  value: stats.publishedTrekCount,
                  label: 'Treks',
                  accent: AppColors.secondary,
                  animate: animate,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _StatTile(
                  icon: AppIcons.ticket,
                  value: stats.registrationCount,
                  label: 'Signups',
                  accent: AppColors.accent,
                  animate: animate,
                ),
              ),
            ],
          ),
        ),
        if (notice != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            notice!,
            style: AppTextStyles.secondary(AppTextStyles.bodySmall),
          ),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
    required this.animate,
  });

  final IconData icon;
  final int value;
  final String label;
  final Color accent;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    // Over the flat page background there's nothing to frost, so blur is
    // off (cheaper, identical look) — same call the Phase 1 GlassCard doc
    // recommends for tiles/lists.
    return GlassCard(
      blurEnabled: false,
      glowColor: accent,
      glowOpacity: 0.14,
      borderRadius: AppRadius.card,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xl,
        horizontal: AppSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: 26, color: accent),
          const SizedBox(height: AppSpacing.md),
          _CountUp(value: value, animate: animate, color: accent),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label.toUpperCase(),
            style: AppTextStyles.statLabel,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Animates a stat from 0 up to [value] once on build, then holds. Purely
/// presentational — the number shown always lands exactly on [value].
class _CountUp extends StatelessWidget {
  const _CountUp({
    required this.value,
    required this.animate,
    required this.color,
  });

  final int value;
  final bool animate;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.tinted(AppTextStyles.statMedium, color);
    if (!animate || value == 0) {
      return Text('$value', style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: AppMotion.slow,
      curve: AppMotion.emphasized,
      builder: (context, v, _) => Text('${v.round()}', style: style),
    );
  }
}
