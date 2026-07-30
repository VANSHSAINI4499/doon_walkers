import 'package:cached_network_image/cached_network_image.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/level_badge.dart';
import 'package:doon_walkers/features/community/domain/entities/member_directory_entry.dart';
import 'package:doon_walkers/features/community/presentation/providers/community_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
                prefixIcon: const AppIcon(AppIcons.search),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const AppIcon(AppIcons.close),
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

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return _MemberDirectoryRow(member: member, index: index);
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

class _MemberDirectoryRow extends StatelessWidget {
  const _MemberDirectoryRow({required this.member, required this.index});

  final MemberDirectoryEntry member;
  final int index;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    // Staggered slide and fade entrance animation:
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 40).clamp(0, 250)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0.0, 16.0 * (1.0 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        child: AppCard(
          onTap: () => context.push('/community/members/profile', extra: member),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.primarySubtle,
                  border: Border.all(color: palette.border, width: 1.5),
                ),
                child: ClipOval(
                  child: member.avatarUrl != null && member.avatarUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: member.avatarUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _Initials(member.displayName),
                        )
                      : _Initials(member.displayName),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Name and Level Badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      member.displayName,
                      style: AppTextStyles.titleSmall.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    LevelBadge(level: member.level, compact: true),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Points
              Text(
                '${member.totalPoints} pts',
                style: AppTextStyles.titleSmall.copyWith(
                  color: palette.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Chevron
              AppIcon(
                AppIcons.chevronRight,
                size: 20,
                color: palette.textDisabled,
              ),
            ],
          ),
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

class _DirectorySkeleton extends StatelessWidget {
  const _DirectorySkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: 8,
        separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) => const SkeletonBox(
          height: 72,
          borderRadius: AppRadius.card,
        ),
      ),
    );
  }
}
