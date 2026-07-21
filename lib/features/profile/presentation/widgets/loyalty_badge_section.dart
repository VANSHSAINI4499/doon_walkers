import 'package:doon_walkers/features/profile/domain/loyalty_badge.dart';
import 'package:doon_walkers/features/registrations/presentation/providers/registration_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The member's current loyalty badge plus a "X more treks to (next)"
/// nudge, both derived from [myRegistrationStatsProvider]'s attended
/// count via [loyaltyBadgeFor]/[nextLoyaltyBadgeAfter].
class LoyaltyBadgeSection extends ConsumerWidget {
  const LoyaltyBadgeSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statsAsync = ref.watch(myRegistrationStatsProvider);

    return statsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
      data: (stats) {
        final attended = stats.totalAttended;
        final badge = loyaltyBadgeFor(attended);
        final next = nextLoyaltyBadgeAfter(attended);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.military_tech_rounded,
                color: theme.colorScheme.onPrimaryContainer,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      badge.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      next == null
                          ? "You've reached the top of the ladder!"
                          : '${next.minAttended - attended} more trek'
                              '${next.minAttended - attended == 1 ? '' : 's'} '
                              'to ${next.name}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
