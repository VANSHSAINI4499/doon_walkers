import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Call-to-action card at the bottom of Home.
///
/// Logic is unchanged from before (and the same design choice, re-flagged
/// per the original brief): a signed-in member sees "You're a Member!"
/// with a button that routes to Profile rather than a static no-op label,
/// so they get somewhere useful to go; a guest gets the join CTA. The
/// same guard against flashing guest copy at a member whose `public.users`
/// row hasn't resolved yet is preserved.
///
/// Visually it's now a glowing [GlassCard] with a [PremiumButton] CTA.
class JoinCommunitySection extends ConsumerWidget {
  const JoinCommunitySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final hasSession = Supabase.instance.client.auth.currentUser != null;

    // A signed-in user's public.users row hasn't resolved yet — avoid
    // flashing "guest" CTA copy at someone who's actually a member.
    if (hasSession && userAsync.isLoading && !userAsync.hasValue) {
      return const GlassCard(
        blurEnabled: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SkeletonCircle(size: 56),
            SizedBox(height: AppSpacing.lg),
            SkeletonBox(width: 180, height: 18),
            SizedBox(height: AppSpacing.md),
            SkeletonText(lines: 2, lineHeight: 11),
            SizedBox(height: AppSpacing.xl),
            SkeletonBox(height: 52, borderRadius: AppRadius.md),
          ],
        ),
      );
    }

    final isMember = userAsync.value != null;

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
            child: AppIcon(
              isMember ? AppIcons.wave : AppIcons.groupAdd,
              size: 34,
              color: AppColors.onPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            isMember ? "You're in the crew! 🎉" : 'Join the community',
            style: AppTextStyles.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            isMember
                ? 'Manage your profile and keep an eye out for new treks.'
                : 'Create a free account to register for treks, comment, and get community updates.',
            style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          PremiumButton(
            label: isMember ? 'Go to Profile' : 'Join Community',
            icon: isMember ? AppIcons.person : AppIcons.groupAdd,
            fullWidth: true,
            onPressed: () => isMember
                ? context.go(AppConstants.routeProfile)
                : context.push(AppConstants.routeSignUp),
          ),
        ],
      ),
    );
  }
}
