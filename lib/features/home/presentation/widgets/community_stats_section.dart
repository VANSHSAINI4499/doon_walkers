import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/home/domain/entities/community_stats.dart';
import 'package:doon_walkers/features/home/presentation/providers/community_stats_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Two aggregate stat tiles (members / treks) sourced from
/// `get_community_stats()` via [communityStatsProvider]. The
/// registrations ("Signups") tile was removed outright — [CommunityStats]
/// still fetches and carries `registrationCount`, this widget just no
/// longer displays it.
///
/// The member count is never shown exact — [_bucketedMemberCount] rounds
/// it down to a "N+" milestone, since a precise headcount is more
/// surveillance-y than useful on a small, growing community's public
/// landing screen. Below the smallest milestone the raw count shows
/// as-is; rounding a single-digit number down would read as a bug, not
/// a feature.
///
/// Data behaviour is otherwise unchanged from before: a fetch failure
/// renders the same tiles zeroed-out with a small "unavailable" caption
/// rather than a hard error box — this is decorative content on a
/// public landing screen, and the real error still lives in the
/// [AsyncValue] for anyone inspecting state, just softened visually.
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

/// Milestones the member count rounds DOWN to, shown as "N+". Below
/// [_memberMilestones.first], the exact count shows instead (no "+") —
/// there's nothing to hide at single/low-double digits, and rounding
/// there would just look wrong.
const _memberMilestones = [10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000];

/// Returns the display number and suffix for a member count — e.g. `137`
/// becomes `(100, '+')`, `7` stays `(7, '')`.
(int, String) _bucketedMemberCount(int count) {
  if (count < _memberMilestones.first) return (count, '');
  var milestone = _memberMilestones.first;
  for (final m in _memberMilestones) {
    if (count >= m) milestone = m;
  }
  return (milestone, '+');
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats, this.notice});

  final CommunityStats stats;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    // Zeroed error state shouldn't animate a count-up from 0 to 0.
    final animate = notice == null;
    final (memberValue, memberSuffix) = _bucketedMemberCount(stats.memberCount);

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatTile(
                  icon: AppIcons.group,
                  value: memberValue,
                  suffix: memberSuffix,
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
    this.suffix = '',
  });

  final IconData icon;
  final int value;
  final String suffix;
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
          _CountUp(value: value, suffix: suffix, animate: animate, color: accent),
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
/// [suffix] (e.g. `'+'` for a bucketed member count) is static chrome
/// around the animated digits, not itself animated.
class _CountUp extends StatelessWidget {
  const _CountUp({
    required this.value,
    required this.animate,
    required this.color,
    this.suffix = '',
  });

  final int value;
  final String suffix;
  final bool animate;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.tinted(AppTextStyles.statMedium, color);
    if (!animate || value == 0) {
      return Text('$value$suffix', style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: AppMotion.slow,
      curve: AppMotion.emphasized,
      builder: (context, v, _) => Text('${v.round()}$suffix', style: style),
    );
  }
}
