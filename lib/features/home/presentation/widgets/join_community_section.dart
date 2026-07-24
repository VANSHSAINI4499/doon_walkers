import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Guest-only join CTA at the bottom of Home.
///
/// The signed-in-member variant ("You're in the crew! -> Go to Profile")
/// was removed outright — Profile is already a main bottom-nav tab, so a
/// second, redundant path to the exact same place served no purpose.
/// Renders nothing at all once there's an active session; only the guest
/// half of this section survives, unchanged.
///
/// Watches [authStateChangesProvider] purely so this rebuilds the moment
/// a guest signs in while Home is still mounted — same "reactivity only"
/// reasoning [myWishlistProvider] etc. use for the same provider.
///
/// Visually it's a glowing [GlassCard] with a [PremiumButton] CTA.
class JoinCommunitySection extends ConsumerWidget {
  const JoinCommunitySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authStateChangesProvider);
    if (Supabase.instance.client.auth.currentUser != null) {
      return const SizedBox.shrink();
    }

    return GlassCard(
      blurEnabled: false,
      glowColor: AppColors.primary,
      glowOpacity: 0.2,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: AppGradients.primary,
              shape: BoxShape.circle,
              boxShadow: AppShadows.glow(AppColors.primary, opacity: 0.4),
            ),
            child: const AppIcon(AppIcons.groupAdd, size: 34, color: AppColors.onPrimary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Join the community',
            style: AppTextStyles.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Create a free account to register for treks, comment, and get community updates.',
            style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          PremiumButton(
            label: 'Join Community',
            icon: AppIcons.groupAdd,
            fullWidth: true,
            onPressed: () => context.push(AppConstants.routeSignUp),
          ),
        ],
      ),
    );
  }
}
