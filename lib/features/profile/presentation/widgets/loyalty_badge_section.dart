import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/profile/domain/loyalty_badge.dart';
import 'package:doon_walkers/features/registrations/presentation/providers/registration_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The member's current loyalty badge plus a "X more treks to (next)"
/// nudge, both derived from [myRegistrationStatsProvider]'s attended count
/// via [loyaltyBadgeFor]/[nextLoyaltyBadgeAfter].
///
/// Phase 14 restyles it calm: a flat card with a gold medal disc, no glow
/// or gradient. Gold is sanctioned here — it is an achievement badge, the
/// one place the palette allows a metal. The computation
/// (attendance-based, from `totalAttended`) is untouched.
class LoyaltyBadgeSection extends ConsumerWidget {
  const LoyaltyBadgeSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(myRegistrationStatsProvider);

    return statsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
      data: (stats) {
        final attended = stats.totalAttended;
        final badge = loyaltyBadgeFor(attended);
        final next = nextLoyaltyBadgeAfter(attended);

        final palette = AppPalette.of(context);

        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: palette.gold,
                  shape: BoxShape.circle,
                ),
                child: AppIcon(
                  AppIcons.medal,
                  color: palette.cardHigh,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'LOYALTY BADGE',
                      style: AppTextStyles.overline.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      badge.name,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      next == null
                          ? "You've reached the top of the ladder!"
                          : '${next.minAttended - attended} more trek'
                              '${next.minAttended - attended == 1 ? '' : 's'} '
                              'to ${next.name}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: palette.textSecondary,
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
