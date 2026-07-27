import 'package:cached_network_image/cached_network_image.dart';
import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/auth/domain/entities/user_entity.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/level_badge.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/my_inquiries_section.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/my_wishlist_section.dart';
import 'package:doon_walkers/features/profile/presentation/controllers/profile_controller.dart';
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
/// ## Phase 27: Profile Photo & Display Name Editing
///
/// Profile photo upload with caching, storage bucket RLS, display name editing,
/// and fallback to initials avatar.
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

/// Identity: avatar photo (with camera edit affordance), display name
/// (with inline edit button), email, role, level, and member since date.
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
    final profileState = ref.watch(profileControllerProvider);
    final isUploading = profileState.isLoading;

    final hasAvatar = user.avatarUrl != null && user.avatarUrl!.isNotEmpty;

    return AppCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar Stack
          SizedBox(
            width: 86,
            height: 86,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.primarySubtle,
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.border, width: 2),
                  ),
                  child: ClipOval(
                    child: hasAvatar
                        ? CachedNetworkImage(
                            imageUrl: user.avatarUrl!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: palette.surface,
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: palette.primary,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Center(
                              child: Text(
                                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                style: AppTextStyles.displaySmall.copyWith(
                                  color: palette.primary,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                              style: AppTextStyles.displaySmall.copyWith(
                                color: palette.primary,
                              ),
                            ),
                          ),
                  ),
                ),
                if (isUploading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: palette.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Material(
                    color: palette.primary,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: isUploading
                          ? null
                          : () => _showAvatarOptionsSheet(context, ref, user),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: AppIcon(
                          AppIcons.camera,
                          size: 16,
                          color: palette.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Name + Edit icon row
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
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
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                icon: AppIcon(AppIcons.edit, size: 18, color: palette.textSecondary),
                tooltip: 'Edit name',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _showEditNameDialog(context, ref, user.name),
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

  void _showAvatarOptionsSheet(
      BuildContext context, WidgetRef ref, UserEntity user) {
    final palette = AppPalette.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: AppIcon(AppIcons.photo, color: palette.primary),
              title: Text('Choose from gallery', style: AppTextStyles.titleMedium),
              onTap: () async {
                Navigator.of(context).pop();
                final success = await ref
                    .read(profileControllerProvider.notifier)
                    .uploadAvatarFromGallery();
                if (!success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          const Text('Failed to upload photo. Please try again.'),
                      backgroundColor: palette.danger,
                    ),
                  );
                }
              },
            ),
            if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
              ListTile(
                leading: AppIcon(AppIcons.delete, color: palette.danger),
                title: Text('Remove photo',
                    style: AppTextStyles.titleMedium
                        .copyWith(color: palette.danger)),
                onTap: () async {
                  Navigator.of(context).pop();
                  final success = await ref
                      .read(profileControllerProvider.notifier)
                      .removeAvatar();
                  if (!success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Failed to remove photo.'),
                        backgroundColor: palette.danger,
                      ),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showEditNameDialog(
      BuildContext context, WidgetRef ref, String currentName) {
    final controller = TextEditingController(text: currentName);
    final formKey = GlobalKey<FormState>();
    final palette = AppPalette.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Display Name'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            maxLength: 50,
            decoration: const InputDecoration(
              labelText: 'Display Name',
              hintText: 'Enter your name',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Name cannot be empty';
              }
              if (value.trim().length > 50) {
                return 'Must be 50 characters or less';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final newName = controller.text.trim();
                Navigator.of(context).pop();
                final success = await ref
                    .read(profileControllerProvider.notifier)
                    .updateDisplayName(newName);
                if (!success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Failed to update display name.'),
                      backgroundColor: palette.danger,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
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
