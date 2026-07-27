import 'package:cached_network_image/cached_network_image.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/level_badge.dart';
import 'package:doon_walkers/features/community/domain/entities/member_directory_entry.dart';
import 'package:doon_walkers/features/community/presentation/providers/community_providers.dart';
import 'package:doon_walkers/features/community/presentation/widgets/member_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MemberDirectoryScreen extends ConsumerStatefulWidget {
  const MemberDirectoryScreen({super.key});

  @override
  ConsumerState<MemberDirectoryScreen> createState() =>
      _MemberDirectoryScreenState();
}

class _MemberDirectoryScreenState extends ConsumerState<MemberDirectoryScreen> {
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
    final membersAsync = ref.watch(
      memberDirectoryProvider((
        limit: 50,
        offset: 0,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      )),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Member Directory')),
      body: Column(
        children: [
          // Search Input Bar
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                hintText: 'Search members by name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchQuery.isNotEmpty
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

          // Member Grid
          Expanded(
            child: membersAsync.when(
              loading: () => const _DirectorySkeleton(),
              error:
                  (err, stack) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppIcon(
                            AppIcons.error,
                            size: 36,
                            color: palette.danger,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Could not load member directory.',
                            style: AppTextStyles.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppButton(
                            label: 'Retry',
                            icon: AppIcons.refresh,
                            onPressed:
                                () => ref.invalidate(
                                  memberDirectoryProvider((
                                    limit: 50,
                                    offset: 0,
                                    search:
                                        _searchQuery.isEmpty
                                            ? null
                                            : _searchQuery,
                                  )),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
              data: (members) {
                if (members.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: Text(
                        _searchQuery.isEmpty
                            ? 'No community members found yet.'
                            : 'No members match "$_searchQuery"',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: palette.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return _MemberCard(member: member);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member});

  final MemberDirectoryEntry member;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return AppCard(
      onTap:
          () => showMemberDetailSheet(
            context: context,
            displayName: member.displayName,
            avatarUrl: member.avatarUrl,
            level: member.level,
            totalPoints: member.totalPoints,
            createdAt: member.createdAt,
          ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.primarySubtle,
              border: Border.all(color: palette.border, width: 1.5),
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
          const SizedBox(height: AppSpacing.sm),
          Text(
            member.displayName,
            style: AppTextStyles.titleSmall.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          LevelBadge(level: member.level),
          const SizedBox(height: 4),
          Text(
            '${member.totalPoints} pts',
            style: AppTextStyles.labelSmall.copyWith(
              color: palette.primary,
              fontWeight: FontWeight.bold,
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
        style: AppTextStyles.titleMedium.copyWith(
          color: palette.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _DirectorySkeleton extends StatelessWidget {
  const _DirectorySkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: 0.82,
        ),
        itemCount: 6,
        itemBuilder:
            (context, index) =>
                const SkeletonBox(height: 140, borderRadius: AppRadius.card),
      ),
    );
  }
}
