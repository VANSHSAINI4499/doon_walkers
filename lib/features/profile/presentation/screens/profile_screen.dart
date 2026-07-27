import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/auth/domain/entities/user_entity.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/level_badge.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/my_inquiries_section.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/my_wishlist_section.dart';
import 'package:doon_walkers/features/profile/presentation/providers/points_providers.dart';
import 'package:doon_walkers/features/profile/presentation/widgets/loyalty_badge_section.dart';
import 'package:doon_walkers/features/profile/presentation/widgets/points_summary_section.dart';
import 'package:doon_walkers/features/profile/presentation/widgets/recent_achievements_section.dart';
import 'package:doon_walkers/features/profile/presentation/widgets/profile_stats_section.dart';
import 'package:doon_walkers/features/profile/presentation/widgets/streak_section.dart';
import 'package:doon_walkers/features/registrations/presentation/widgets/my_registrations_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The Profile tab — who you are and what you've done.
///
/// ## Phase 14: Profile and Settings split apart
///
/// Everything that was a *control* moved to the Settings screen, leaving
/// Profile as a read surface. Removed from here:
///
///  - **Sign Out** → Settings → Account (and it now confirms first).
///  - **Leaderboard visibility** → Settings → Privacy. Same column, same
///    write path, just not in two places.
///  - **Admin tools** → gone entirely. The drawer's Admin section (Phase
///    10) already reaches Registrations, Merchandise Inquiries and Send
///    Notification from any screen; this group was a second copy, and
///    adding a third in Settings would have been worse. See
///    SettingsScreen's doc.
///
/// What stays is the member's own record: identity, real stats, the
/// attendance-derived loyalty badge, the Trekking Streak, and their own
/// registrations / wishlist / inquiries.
///
/// ## Phase 22: Points & Levels surfaced
///
/// The level badge next to the name and the points summary card both
/// read from `get_my_points_summary()`
/// (0039_points_history_and_enrollment_fix.sql) — the level ladder
/// itself lives ONLY in that RPC's `level_for_points()`/
/// `points_for_level()` functions, never reimplemented here. "View
/// History" opens the full ledger at [AppConstants.routePointsHistory].
/// [LevelBadge] is the same widget Phase 21's challenge leaderboard
/// already uses — one level-badge widget in the codebase, not two.
///
/// ## Omitted from the reference, deliberately
///
/// No photo upload (no Storage bucket or picker for it), no "View
/// Membership" card (there is no membership tier system — the loyalty
/// badge is attendance-derived and already shown). No separate
/// Achievements grid either: `user_achievements` exists as a schema
/// (0036_phase19_schema_foundations.sql) but nothing anywhere awards
/// into it, so it would always render empty — the real "what have I
/// earned" answer is already the loyalty badge plus [ProfileStatsSection]'s
/// tiers-earned count, both shown below. No "Events" stat (no events
/// concept exists).
///
/// **"Member since" is new and real** — `users.created_at`, which has
/// always been there.
///
/// The Trekking Streak remains a deliberately separate system from the
/// Challenges module's fitness streaks: months with an attended trek, not
/// days of recorded activity.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const AppIcon(AppIcons.settings),
            tooltip: 'Settings',
            onPressed: () => context.push(AppConstants.routeSettings),
          ),
        ],
      ),
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
                  AppIcon(AppIcons.error, size: 40, color: palette.danger),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Could not load your profile.',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: palette.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: 'Retry',
                    icon: AppIcons.refresh,
                    variant: AppButtonVariant.glass,
                    size: AppButtonSize.small,
                    onPressed: () => ref.invalidate(currentUserProvider),
                  ),
                ],
              ),
            ),
          );
        },
        data: (user) {
          if (user == null) {
            return Center(
              child: Text(
                'No active session found.',
                style: AppTextStyles.titleMedium.copyWith(
                  color: palette.textPrimary,
                ),
              ),
            );
          }

          final blocks = <Widget>[
            _ProfileHeader(user: user),
            const PointsSummarySection(),
            const RecentAchievementsSection(),
            const LoyaltyBadgeSection(),
            // Renders nothing until there's a real streak, so it never
            // leaves an empty gap for a brand-new member.
            const StreakSection(),
            const ProfileStatsSection(),
            const MyRegistrationsSection(),
            const MyWishlistSection(),
            const MyInquiriesSection(),
          ];

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < blocks.length; i++)
                      AppReveal(
                        index: i.clamp(0, 8),
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: i == blocks.length - 1
                                ? 0
                                : AppSpacing.lg,
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

/// Identity: initial, name, email, role, level, and how long they've
/// been a member.
class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.user});

  final UserEntity user;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final created = user.createdAt.toLocal();
    final level = ref.watch(myPointsSummaryProvider).valueOrNull?.level;

    return AppCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.primarySubtle,
              shape: BoxShape.circle,
            ),
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              style: AppTextStyles.displaySmall.copyWith(
                color: palette.primary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  user.name.isNotEmpty ? user.name : 'Doon Walkers Member',
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: palette.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (level != null) ...[
                const SizedBox(width: AppSpacing.sm),
                LevelBadge(level: level),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            user.email,
            style: AppTextStyles.bodyMedium.copyWith(
              color: palette.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (user.isAdmin) const _RoleBadge(),
              // Real `users.created_at` — the one reference element on this
              // card that the schema genuinely backs.
              _Pill(
                icon: AppIcons.calendar,
                label:
                    'Member since ${_months[created.month - 1]} '
                    '${created.year}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: palette.primary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(AppIcons.verified, size: 13, color: palette.onPrimary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Administrator',
            style: AppTextStyles.labelSmall.copyWith(color: palette.onPrimary),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: palette.cardHigh,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: 13, color: palette.textSecondary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton while the current user loads.
class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Shimmer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: palette.card,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: palette.border),
                  ),
                  child: const Column(
                    children: [
                      SkeletonCircle(size: 76),
                      SizedBox(height: AppSpacing.lg),
                      SkeletonBox(width: 160, height: 22),
                      SizedBox(height: AppSpacing.sm),
                      SkeletonBox(width: 200, height: 12),
                      SizedBox(height: AppSpacing.lg),
                      SkeletonBox(width: 140, height: 24),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const SkeletonBox(height: 96, borderRadius: AppRadius.card),
                const SizedBox(height: AppSpacing.lg),
                const SkeletonBox(height: 120, borderRadius: AppRadius.card),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
