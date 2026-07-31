import 'package:cached_network_image/cached_network_image.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/activity/presentation/providers/activity_dashboard_providers.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/level_badge.dart';
import 'package:doon_walkers/features/community/domain/entities/member_directory_entry.dart';
import 'package:doon_walkers/features/registrations/presentation/providers/registration_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MemberProfileScreen extends ConsumerWidget {
  const MemberProfileScreen({super.key, required this.member});

  final MemberDirectoryEntry member;

  String _formatMemberSince(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return 'Member since ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final currentUserId = ref.watch(currentUserIdProvider);
    final isCurrentUser = member.userId == currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Member Profile'),
        leading: IconButton(
          icon: const AppIcon(AppIcons.back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile Header
            Align(
              alignment: Alignment.center,
              child: Column(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: palette.primarySubtle,
                      border: Border.all(color: palette.border, width: 2),
                      boxShadow: AppShadows.of(palette),
                    ),
                    child: ClipOval(
                      child: member.avatarUrl != null && member.avatarUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: member.avatarUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _InitialsLarge(member.displayName),
                            )
                          : _InitialsLarge(member.displayName),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          member.displayName,
                          style: AppTextStyles.headlineSmall.copyWith(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      LevelBadge(level: member.level),
                    ],
                  ),
                  if (member.createdAt != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _formatMemberSince(member.createdAt!),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Statistics Section
            Text(
              'Trek Statistics',
              style: AppTextStyles.titleMedium.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (isCurrentUser)
              _MyStatsGrid()
            else
              _PrivateStatsGrid(palette: palette),

            const SizedBox(height: AppSpacing.xxl),

            // Achievements Section
            Text(
              'Recent Achievements',
              style: AppTextStyles.titleMedium.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (isCurrentUser)
              _MyAchievementsList()
            else
              _PrivateAchievementsPlaceholder(palette: palette),

            const SizedBox(height: AppSpacing.xxl),

            // Badges Section (Coming Soon)
            Text(
              'Loyalty Badges',
              style: AppTextStyles.titleMedium.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _LoyaltyBadgesComingSoon(palette: palette),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _InitialsLarge extends StatelessWidget {
  const _InitialsLarge(this.name);
  final String name;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: AppTextStyles.headlineMedium.copyWith(
          color: palette.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _MyStatsGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final statsAsync = ref.watch(myRegistrationStatsProvider);
    final streakAsync = ref.watch(myStreakProvider);

    return statsAsync.when(
      loading: () => const _StatsGridSkeleton(),
      error: (_, __) => _ErrorPlaceholder(palette: palette),
      data: (stats) {
        final streak = streakAsync.valueOrNull?.currentMonths ?? 0;

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.3,
          children: [
            _StatCard(
              icon: AppIcons.rupee, // Points / value
              value: '${stats.totalRegistered * 100 + stats.totalAttended * 500}',
              label: 'Community Points',
              palette: palette,
            ),
            _StatCard(
              icon: AppIcons.ticket,
              value: '${stats.totalRegistered}',
              label: 'Treks Joined',
              palette: palette,
            ),
            _StatCard(
              icon: AppIcons.taskDone,
              value: '${stats.totalAttended}',
              label: 'Treks Completed',
              palette: palette,
            ),
            _StatCard(
              icon: AppIcons.streak,
              value: '$streak',
              label: 'Current Streak (months)',
              palette: palette,
            ),
          ],
        );
      },
    );
  }
}

class _PrivateStatsGrid extends StatelessWidget {
  const _PrivateStatsGrid({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.3,
      children: [
        _StatCard(
          icon: AppIcons.rupee,
          value: '—',
          label: 'Points',
          isPrivate: true,
          palette: palette,
        ),
        _StatCard(
          icon: AppIcons.ticket,
          value: '—',
          label: 'Treks Joined',
          isPrivate: true,
          palette: palette,
        ),
        _StatCard(
          icon: AppIcons.taskDone,
          value: '—',
          label: 'Treks Completed',
          isPrivate: true,
          palette: palette,
        ),
        _StatCard(
          icon: AppIcons.streak,
          value: '—',
          label: 'Current Streak',
          isPrivate: true,
          palette: palette,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.palette,
    this.isPrivate = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final AppPalette palette;
  final bool isPrivate;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              AppIcon(
                isPrivate ? AppIcons.lock : icon,
                size: 18,
                color: palette.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: palette.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // FittedBox as a safety net on top of the taller
          // childAspectRatio below — the grid cell's height is fixed
          // (GridView.count), so at a large system text-scale factor
          // this value text is the one thing here that could still
          // outgrow the cell; scaling it down slightly is preferable to
          // a RenderFlex overflow, and is a no-op at normal text sizes.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              isPrivate ? 'Private' : value,
              style: AppTextStyles.titleLarge.copyWith(
                color: isPrivate ? palette.textDisabled : palette.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MyAchievementsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final achievementsAsync = ref.watch(userAchievementsProvider);

    return achievementsAsync.when(
      loading: () => const Shimmer(
        child: SkeletonBox(height: 72, borderRadius: AppRadius.card),
      ),
      error: (_, __) => _ErrorPlaceholder(palette: palette),
      data: (achievements) {
        if (achievements.isEmpty) {
          return AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: Text(
                'No achievements unlocked yet.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ),
          );
        }

        return SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: achievements.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final ach = achievements[index];
              return Container(
                width: 220,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: palette.card,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: palette.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: palette.primarySubtle,
                        shape: BoxShape.circle,
                      ),
                      child: AppIcon(
                        AppIcons.medal,
                        size: 24,
                        color: palette.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            ach.title,
                            style: AppTextStyles.titleSmall.copyWith(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            ach.description,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: palette.textSecondary,
                              fontSize: 10,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _PrivateAchievementsPlaceholder extends StatelessWidget {
  const _PrivateAchievementsPlaceholder({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppIcon(AppIcons.lock, size: 16, color: palette.textDisabled),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              'Achievements are private to this member.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: palette.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoyaltyBadgesComingSoon extends StatelessWidget {
  const _LoyaltyBadgesComingSoon({required this.palette});

  final AppPalette palette;

  Widget _buildBadgeWidget(BuildContext context, String title) {
    return Tooltip(
      message: 'Loyalty badges are coming soon!',
      triggerMode: TooltipTriggerMode.tap,
      child: Opacity(
        opacity: 0.5,
        child: Container(
          width: 90,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(
                AppIcons.premium,
                size: 28,
                color: palette.textDisabled,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: AppTextStyles.labelSmall.copyWith(
                  color: palette.textDisabled,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildBadgeWidget(context, 'Pioneer'),
        _buildBadgeWidget(context, 'Summit Seeker'),
        _buildBadgeWidget(context, 'Streak Master'),
      ],
    );
  }
}

class _StatsGridSkeleton extends StatelessWidget {
  const _StatsGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.3,
        children: List.generate(
          4,
          (_) => const SkeletonBox(height: 60, borderRadius: AppRadius.card),
        ),
      ),
    );
  }
}

class _ErrorPlaceholder extends StatelessWidget {
  const _ErrorPlaceholder({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          'Failed to load statistics.',
          style: AppTextStyles.bodyMedium.copyWith(color: palette.danger),
        ),
      ),
    );
  }
}
