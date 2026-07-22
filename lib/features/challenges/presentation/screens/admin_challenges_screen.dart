import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/challenge_admin_actions.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/challenge_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Admin challenge management — every challenge, active and draft.
///
/// This is the index screen of its own admin-only bottom-nav tab
/// ("Challenges" — see AppShell/app_router.dart's Branch 4 doc), not a
/// Profile-card destination; `challenges_select`/`_admin` RLS backs the
/// gating up independently either way. No public Challenges tab exists
/// yet to double as a "real" browsing surface — that's C2 — so this
/// list is plain (no photos, no masonry grid, no search/filter): title,
/// metric/window at a glance, active/draft state, and the same inline
/// admin-actions menu Trek Library/Merchandise use.
class AdminChallengesScreen extends ConsumerWidget {
  const AdminChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final challengesAsync = ref.watch(adminAllChallengesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Challenges')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppConstants.routeAdminChallengesNew),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Challenge'),
      ),
      body: SafeArea(
        child: challengesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) {
            debugPrint('AdminChallengesScreen: failed to load challenges: $error');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 40, color: theme.colorScheme.error),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load challenges.',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(adminAllChallengesProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          },
          data: (challenges) {
            Future<void> onRefresh() => ref.refresh(adminAllChallengesProvider.future);

            if (challenges.isEmpty) {
              return RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [_EmptyChallenges()],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: challenges.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _ChallengeTile(challenge: challenges[index]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyChallenges extends StatelessWidget {
  const _EmptyChallenges();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_outlined, size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'No challenges yet',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "Add Challenge" to create the first one.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ChallengeTile extends StatelessWidget {
  const _ChallengeTile({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    ChallengeIcon.forKey(challenge.icon),
                    size: 18,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        challenge.title,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${challenge.metric.label} · ${challenge.timeWindow.label}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (!challenge.isActive)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Draft',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ChallengeAdminActions(challenge: challenge),
              ],
            ),
            if (challenge.tiers.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: challenge.tiersAscending
                    .map((t) => _TierChip(
                          label: t.tier.label,
                          value: challenge.metric.formatValue(t.thresholdValue),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TierChip extends StatelessWidget {
  const _TierChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
