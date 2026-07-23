import 'package:doon_walkers/features/registrations/domain/entities/trekking_streak.dart';
import 'package:doon_walkers/features/registrations/presentation/providers/registration_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current + longest attendance streak (Version 2, Phase C3) — placed
/// on Profile right next to [LoyaltyBadgeSection]/[ProfileStatsSection]
/// per the phase brief, same "member's own engagement, at a glance"
/// grouping. Renders nothing on error/loading-with-no-cache rather
/// than a spinner of its own — a stat with nothing to show shouldn't
/// visually compete with the sections around it; see
/// [LoyaltyBadgeSection]'s identical choice.
class StreakSection extends ConsumerWidget {
  const StreakSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(myStreakProvider);

    return streakAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
      data: (streak) {
        if (streak.longestMonths == 0) {
          // Nothing to show yet — a brand-new member with no attended
          // treks. Avoids a "0-month streak" line that reads as a
          // failure state rather than just "not started yet".
          return const SizedBox.shrink();
        }
        return _StreakCard(streak: streak);
      },
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak});

  final TrekkingStreak streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            streak.isActive ? Icons.local_fire_department_rounded : Icons.local_fire_department_outlined,
            color: theme.colorScheme.onSecondaryContainer,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  streak.isActive
                      ? '${streak.currentMonths}-month streak'
                      : 'No active streak right now',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Longest streak: ${streak.longestMonths} month'
                  '${streak.longestMonths == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
