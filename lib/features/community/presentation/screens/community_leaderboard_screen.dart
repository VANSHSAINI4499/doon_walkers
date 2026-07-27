import 'package:cached_network_image/cached_network_image.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/level_badge.dart';
import 'package:doon_walkers/features/community/domain/entities/community_leaderboard_entry.dart';
import 'package:doon_walkers/features/community/presentation/providers/community_providers.dart';
import 'package:doon_walkers/features/community/presentation/widgets/community_podium.dart';
import 'package:doon_walkers/features/community/presentation/widgets/member_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CommunityLeaderboardScreen extends ConsumerStatefulWidget {
  const CommunityLeaderboardScreen({super.key});

  @override
  ConsumerState<CommunityLeaderboardScreen> createState() =>
      _CommunityLeaderboardScreenState();
}

class _CommunityLeaderboardScreenState
    extends ConsumerState<CommunityLeaderboardScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final leaderboardAsync =
        ref.watch(communityLeaderboardProvider((limit: 50, offset: 0)));
    final myRankAsync = ref.watch(myCommunityRankProvider);
    final isSignedIn = ref.watch(isSignedInProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Leaderboard'),
      ),
      body: leaderboardAsync.when(
        loading: () => const _LeaderboardSkeleton(),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(AppIcons.error, size: 36, color: palette.danger),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Could not load leaderboard.',
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Retry',
                  icon: AppIcons.refresh,
                  onPressed: () => ref.invalidate(
                      communityLeaderboardProvider((limit: 50, offset: 0))),
                ),
              ],
            ),
          ),
        ),
        data: (entries) {
          final top3 = entries.take(3).toList();
          final rest = entries.skip(3).toList();

          final filteredRest = _searchQuery.isEmpty
              ? rest
              : rest
                  .where((e) => e.displayName
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase()))
                  .toList();

          return Stack(
            children: [
              Column(
                children: [
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) =>
                          setState(() => _searchQuery = val.trim()),
                      decoration: InputDecoration(
                        hintText: 'Search members...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),

                  // Main List
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        100, // Space for sticky bottom rank bar
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_searchQuery.isEmpty && top3.isNotEmpty) ...[
                            CommunityPodium(entries: top3),
                            const SizedBox(height: AppSpacing.xl),
                          ],
                          if (filteredRest.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.xxl),
                              child: Center(
                                child: Text(
                                  _searchQuery.isEmpty
                                      ? 'No leaderboard entries yet.'
                                      : 'No members match "$_searchQuery"',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: palette.textSecondary,
                                  ),
                                ),
                              ),
                            )
                          else
                            ...filteredRest.map(
                              (entry) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: AppSpacing.sm),
                                child: _LeaderboardRow(entry: entry),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Sticky My Rank Bar at Bottom
              if (isSignedIn)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: myRankAsync.when(
                    data: (myEntry) => _StickyRankBar(entry: myEntry),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry});

  final CommunityLeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return AppCard(
      onTap: () => showMemberDetailSheet(
        context: context,
        displayName: entry.displayName,
        avatarUrl: entry.avatarUrl,
        level: entry.level,
        totalPoints: entry.totalPoints,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#${entry.rank}',
              style: AppTextStyles.titleSmall.copyWith(
                color: palette.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.primarySubtle,
            ),
            child: ClipOval(
              child: entry.avatarUrl != null && entry.avatarUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: entry.avatarUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _Initials(entry.displayName),
                    )
                  : _Initials(entry.displayName),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.displayName,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: palette.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                LevelBadge(level: entry.level),
              ],
            ),
          ),
          Text(
            '${entry.totalPoints} pts',
            style: AppTextStyles.titleSmall.copyWith(
              color: palette.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _StickyRankBar extends StatelessWidget {
  const _StickyRankBar({required this.entry});

  final CommunityLeaderboardEntry? entry;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    if (entry == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: palette.primary,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                'Your Rank: #${entry!.rank}',
                style: AppTextStyles.labelMedium.copyWith(
                  color: palette.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Spacer(),
            LevelBadge(level: entry!.level),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${entry!.totalPoints} pts',
              style: AppTextStyles.titleMedium.copyWith(
                color: palette.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
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
        style: AppTextStyles.titleMedium.copyWith(
          color: palette.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _LeaderboardSkeleton extends StatelessWidget {
  const _LeaderboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            const SkeletonBox(height: 120, borderRadius: AppRadius.card),
            const SizedBox(height: AppSpacing.lg),
            for (var i = 0; i < 5; i++) ...[
              const SkeletonBox(height: 60, borderRadius: AppRadius.card),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}
