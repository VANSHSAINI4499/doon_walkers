import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/core/widgets/section_title.dart';
import 'package:doon_walkers/features/auth/domain/entities/user_entity.dart';
import 'package:doon_walkers/features/auth/presentation/controllers/auth_controller.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/admin_merch_inquiries_card.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/my_inquiries_section.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/my_wishlist_section.dart';
import 'package:doon_walkers/features/notifications/presentation/widgets/admin_send_notification_card.dart';
import 'package:doon_walkers/features/profile/presentation/widgets/leaderboard_visibility_toggle.dart';
import 'package:doon_walkers/features/profile/presentation/widgets/loyalty_badge_section.dart';
import 'package:doon_walkers/features/profile/presentation/widgets/profile_stats_section.dart';
import 'package:doon_walkers/features/profile/presentation/widgets/streak_section.dart';
import 'package:doon_walkers/features/registrations/presentation/widgets/my_registrations_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Profile tab.
///
/// Redesign Phase 5: rebuilt on the design system. This is a
/// visual-layer-only rebuild — every section keeps its exact data source,
/// gating, and action. The section order is unchanged: identity + sign
/// out, then the admin-only tools group, then the "engagement at a
/// glance" cards (loyalty badge, the attendance-based **Trekking Streak**,
/// and stats), the leaderboard-visibility toggle, and finally the
/// member's own registrations / wishlist / inquiries lists.
///
/// The Trekking Streak (consecutive months with an attended trek) is a
/// deliberately separate system from the Challenges module's fitness
/// streaks; it renders here labelled and styled distinctly and is not
/// merged with any Challenges content.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: userAsync.when(
        // A transient RealtimeSubscribeException from a WebSocket reconnect
        // shouldn't blow away a still-valid cached profile/role.
        skipError: true,
        loading: () => const _ProfileSkeleton(),
        error: (err, stack) {
          debugPrint('ProfileScreen: failed to load current user: $err');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppIcon(AppIcons.error, size: 44, color: AppColors.danger),
                  const SizedBox(height: AppSpacing.md),
                  Text('Could not load your profile.', style: AppTextStyles.titleMedium, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.xl),
                  PremiumButton(
                    label: 'Retry',
                    icon: AppIcons.refresh,
                    variant: PremiumButtonVariant.glass,
                    size: PremiumButtonSize.small,
                    onPressed: () => ref.invalidate(currentUserProvider),
                  ),
                ],
              ),
            ),
          );
        },
        data: (user) {
          if (user == null) {
            return Center(child: Text('No active session found.', style: AppTextStyles.titleMedium));
          }

          final isUserAdmin = user.role == UserRole.admin;

          // Each entry is one staggered block, in the exact prior order.
          final blocks = <Widget>[
            _ProfileHeader(
              user: user,
              isAdmin: isUserAdmin,
              onSignOut: () => ref.read(authControllerProvider.notifier).signOut(),
            ),
            // Admin-only tools group — the title and both entries are gated
            // together, so a non-admin sees nothing here (the cards also
            // self-gate as defence in depth).
            if (isUserAdmin)
              const _AdminTools(),
            const LoyaltyBadgeSection(),
            // Attendance streak — grouped with the loyalty badge as the
            // "engagement at a glance" pair; renders nothing until there's
            // a real streak to show, so it never leaves an empty gap.
            const StreakSection(),
            const ProfileStatsSection(),
            const LeaderboardVisibilityToggle(),
            const MyRegistrationsSection(),
            const MyWishlistSection(),
            const MyInquiriesSection(),
          ];

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < blocks.length; i++)
                      AppReveal(
                        index: i.clamp(0, 8),
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: i == blocks.length - 1 ? 0 : AppSpacing.xl,
                          ),
                          child: blocks[i],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user, required this.isAdmin, required this.onSignOut});

  final UserEntity user;
  final bool isAdmin;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      glowColor: AppColors.primary,
      glowOpacity: 0.18,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppGradients.primary,
              shape: BoxShape.circle,
              boxShadow: AppShadows.glow(AppColors.primary, opacity: 0.4, radius: 28),
            ),
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              style: AppTextStyles.tinted(AppTextStyles.displaySmall, AppColors.onPrimary),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            user.name.isNotEmpty ? user.name : 'Doon Walkers Member',
            style: AppTextStyles.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            user.email,
            style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          _RoleBadge(isAdmin: isAdmin),
          const SizedBox(height: AppSpacing.xxl),
          PremiumButton(
            label: 'Sign Out',
            icon: AppIcons.logout,
            variant: PremiumButtonVariant.danger,
            fullWidth: true,
            onPressed: onSignOut,
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    if (isAdmin) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 6),
        decoration: BoxDecoration(
          gradient: AppGradients.primary,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: AppShadows.glow(AppColors.primary, opacity: 0.35, radius: 12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon(AppIcons.verified, size: 14, color: AppColors.onPrimary),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'ADMINISTRATOR',
              style: AppTextStyles.tinted(AppTextStyles.labelSmall, AppColors.onPrimary)
                  .copyWith(letterSpacing: 1.2),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
      ),
      child: Text(
        'REGISTERED TREKKER',
        style: AppTextStyles.tinted(AppTextStyles.labelSmall, AppColors.secondaryLight)
            .copyWith(letterSpacing: 1.2),
      ),
    );
  }
}

/// Admin-only tools group. The whole group (title + entries) is gated by
/// the caller; the individual cards also self-gate on [isAdminProvider].
class _AdminTools extends StatelessWidget {
  const _AdminTools();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(title: 'Admin Tools', icon: AppIcons.medal, accent: AppColors.accent),
        SizedBox(height: AppSpacing.md),
        AdminSendNotificationCard(),
        SizedBox(height: AppSpacing.md),
        AdminMerchInquiriesCard(),
      ],
    );
  }
}

/// Skeleton while the current user loads.
class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Shimmer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: const Column(
                    children: [
                      SkeletonCircle(size: 96),
                      SizedBox(height: AppSpacing.lg),
                      SkeletonBox(width: 160, height: 22),
                      SizedBox(height: AppSpacing.sm),
                      SkeletonBox(width: 200, height: 12),
                      SizedBox(height: AppSpacing.xl),
                      SkeletonBox(height: 52, borderRadius: AppRadius.md),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const SkeletonStatRow(count: 2),
                const SizedBox(height: AppSpacing.xl),
                const SkeletonStatRow(count: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
