import 'package:doon_walkers/features/home/domain/entities/community_stats.dart';
import 'package:doon_walkers/features/home/presentation/providers/community_stats_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Three aggregate stat tiles (members / treks / registrations) sourced
/// from `get_community_stats()` via [communityStatsProvider].
///
/// A fetch failure renders the same tiles zeroed-out with a small
/// "unavailable" caption rather than a hard error box — this is
/// decorative content on a public landing screen, not something worth
/// alarming a guest over. The real error is still in [AsyncValue] for
/// anyone inspecting state; it's not swallowed, just softened visually.
class CommunityStatsSection extends ConsumerWidget {
  const CommunityStatsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(communityStatsProvider);

    return statsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      ),
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
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.groups_rounded,
                value: stats.memberCount,
                label: 'Members',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                icon: Icons.terrain_rounded,
                value: stats.publishedTrekCount,
                label: 'Treks',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                icon: Icons.confirmation_number_outlined,
                value: stats.registrationCount,
                label: 'Registrations',
              ),
            ),
          ],
        ),
        if (notice != null) ...[
          const SizedBox(height: 8),
          Text(
            notice!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
  });

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 26),
            const SizedBox(height: 10),
            Text(
              '$value',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
