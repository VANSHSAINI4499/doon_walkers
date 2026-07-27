import 'package:cached_network_image/cached_network_image.dart';
import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/level_badge.dart';
import 'package:doon_walkers/features/community/domain/entities/member_directory_entry.dart';
import 'package:doon_walkers/features/community/presentation/providers/community_providers.dart';
import 'package:doon_walkers/features/community/presentation/widgets/community_podium.dart';
import 'package:doon_walkers/features/community/presentation/widgets/member_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The Community tab root — features real Leaderboard preview, real Members
/// directory horizontal row, and a clean Feed coming soon card.
class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(isSignedInProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Community')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isSignedIn) ...[
              const _GuestCommunityBanner(),
              const SizedBox(height: AppSpacing.xl),
            ],

            // Section A: Community Leaderboard Preview
            const _LeaderboardPreviewSection(),
            const SizedBox(height: AppSpacing.xxl),

            // Section B: Members Section
            const _MembersPreviewSection(),
            const SizedBox(height: AppSpacing.xxl),

            // Section C: Social Feed Placeholder
            const _FeedPlaceholderCard(),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

/// Section A: Leaderboard Preview
class _LeaderboardPreviewSection extends ConsumerWidget {
  const _LeaderboardPreviewSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final leaderboardAsync = ref.watch(
      communityLeaderboardProvider((limit: 10, offset: 0)),
    );
    final myRankAsync = ref.watch(myCommunityRankProvider);
    final isSignedIn = ref.watch(isSignedInProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Leaderboard',
              style: AppTextStyles.titleLarge.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/community/leaderboard'),
              child: const Text('View Full Leaderboard'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        leaderboardAsync.when(
          loading: () => const _SectionSkeleton(),
          error:
              (err, stack) => Text(
                'Could not load leaderboard.',
                style: AppTextStyles.bodyMedium.copyWith(color: palette.danger),
              ),
          data: (entries) {
            if (entries.isEmpty) {
              return AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Center(
                    child: Text(
                      'No leaderboard data yet.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }

            final top3 = entries.take(3).toList();
            final rest = entries.skip(3).toList();

            return AppCard(
              child: Column(
                children: [
                  CommunityPodium(entries: top3),
                  if (rest.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    const Divider(),
                    const SizedBox(height: AppSpacing.sm),
                    for (final entry in rest)
                      ListTile(
                        dense: true,
                        leading: SizedBox(
                          width: 32,
                          child: Text(
                            '#${entry.rank}',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: palette.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          entry.displayName,
                          style: AppTextStyles.titleSmall,
                        ),
                        subtitle: LevelBadge(level: entry.level),
                        trailing: Text(
                          '${entry.totalPoints} pts',
                          style: AppTextStyles.titleSmall.copyWith(
                            color: palette.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap:
                            () => showMemberDetailSheet(
                              context: context,
                              displayName: entry.displayName,
                              avatarUrl: entry.avatarUrl,
                              level: entry.level,
                              totalPoints: entry.totalPoints,
                            ),
                      ),
                  ],
                  if (isSignedIn) ...[
                    const SizedBox(height: AppSpacing.md),
                    myRankAsync.when(
                      data: (myEntry) {
                        if (myEntry == null) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: palette.primarySubtle,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border: Border.all(color: palette.primary),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Your Rank: #${myEntry.rank}',
                                style: AppTextStyles.titleSmall.copyWith(
                                  color: palette.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              LevelBadge(level: myEntry.level),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                '${myEntry.totalPoints} pts',
                                style: AppTextStyles.titleSmall.copyWith(
                                  color: palette.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Section B: Members Preview
class _MembersPreviewSection extends ConsumerWidget {
  const _MembersPreviewSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final membersAsync = ref.watch(
      memberDirectoryProvider((limit: 8, offset: 0, search: null)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Members',
              style: AppTextStyles.titleLarge.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/community/members'),
              child: const Text('View All Members'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        membersAsync.when(
          loading: () => const _SectionSkeleton(),
          error:
              (err, stack) => Text(
                'Could not load members.',
                style: AppTextStyles.bodyMedium.copyWith(color: palette.danger),
              ),
          data: (members) {
            if (members.isEmpty) {
              return AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Center(
                    child: Text(
                      'No other members found.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }

            return SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: members.length,
                separatorBuilder:
                    (context, index) => const SizedBox(width: AppSpacing.md),
                itemBuilder: (context, index) {
                  final member = members[index];
                  return _MemberChip(member: member);
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _MemberChip extends StatelessWidget {
  const _MemberChip({required this.member});

  final MemberDirectoryEntry member;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return InkWell(
      onTap:
          () => showMemberDetailSheet(
            context: context,
            displayName: member.displayName,
            avatarUrl: member.avatarUrl,
            level: member.level,
            totalPoints: member.totalPoints,
            createdAt: member.createdAt,
          ),
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        width: 90,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.primarySubtle,
              ),
              child: ClipOval(
                child:
                    member.avatarUrl != null && member.avatarUrl!.isNotEmpty
                        ? CachedNetworkImage(
                          imageUrl: member.avatarUrl!,
                          fit: BoxFit.cover,
                          errorWidget:
                              (_, __, ___) => _Initials(member.displayName),
                        )
                        : _Initials(member.displayName),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              member.displayName,
              style: AppTextStyles.labelSmall.copyWith(
                color: palette.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            LevelBadge(level: member.level),
          ],
        ),
      ),
    );
  }
}

/// Section C: Social Feed Placeholder Card
class _FeedPlaceholderCard extends StatelessWidget {
  const _FeedPlaceholderCard();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: palette.primarySubtle,
              shape: BoxShape.circle,
            ),
            child: AppIcon(AppIcons.forum, size: 36, color: palette.primary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Community Feed Coming Soon',
            style: AppTextStyles.titleMedium.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Share your treks, photos, and achievements with fellow DoonWalkers.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: palette.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _GuestCommunityBanner extends StatelessWidget {
  const _GuestCommunityBanner();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.primarySubtle,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: palette.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          AppIcon(AppIcons.info, color: palette.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Sign in to see community members and rank on the leaderboard.',
              style: AppTextStyles.bodySmall.copyWith(
                color: palette.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppButton(
            label: 'Sign in',
            size: AppButtonSize.small,
            onPressed:
                () => context.push(
                  '${AppConstants.routeSignIn}?redirectTo=${Uri.encodeComponent(AppConstants.routeCommunity)}',
                ),
          ),
        ],
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials(this.name);
  final String name;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: AppTextStyles.titleSmall.copyWith(
          color: palette.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Shimmer(
      child: SkeletonBox(height: 100, borderRadius: AppRadius.card),
    );
  }
}
