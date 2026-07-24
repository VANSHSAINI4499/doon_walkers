import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/profile/domain/loyalty_badge.dart';
import 'package:doon_walkers/features/registrations/presentation/providers/registration_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The member's current loyalty badge plus a "X more treks to (next)"
/// nudge, both derived from [myRegistrationStatsProvider]'s attended count
/// via [loyaltyBadgeFor]/[nextLoyaltyBadgeAfter].
///
/// Redesign Phase 5 restyles this onto a gold-glowing glass card. The
/// computation (attendance-based, from `totalAttended`) is untouched.
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

        return GlassCard(
          blurEnabled: false,
          glowColor: AppColors.gold,
          glowOpacity: 0.16,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppGradients.gold,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.glow(AppColors.gold, opacity: 0.4, radius: 14),
                ),
                child: const AppIcon(AppIcons.medal, color: AppColors.background, size: 26),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('LOYALTY BADGE', style: AppTextStyles.tinted(AppTextStyles.overline, AppColors.gold)),
                    const SizedBox(height: 2),
                    Text(badge.name, style: AppTextStyles.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      next == null
                          ? "You've reached the top of the ladder!"
                          : '${next.minAttended - attended} more trek'
                              '${next.minAttended - attended == 1 ? '' : 's'} '
                              'to ${next.name}',
                      style: AppTextStyles.secondary(AppTextStyles.bodySmall),
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
