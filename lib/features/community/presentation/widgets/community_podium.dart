import 'package:cached_network_image/cached_network_image.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/level_badge.dart';
import 'package:doon_walkers/features/community/domain/entities/community_leaderboard_entry.dart';
import 'package:flutter/material.dart';

class CommunityPodium extends StatelessWidget {
  const CommunityPodium({
    super.key,
    required this.entries,
  });

  /// Up to 3 top entries.
  final List<CommunityLeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final first = entries.isNotEmpty ? entries[0] : null;
    final second = entries.length > 1 ? entries[1] : null;
    final third = entries.length > 2 ? entries[2] : null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (second != null)
          Expanded(child: _PodiumColumn(entry: second, position: 2, height: 110))
        else
          const Spacer(),
        const SizedBox(width: AppSpacing.sm),
        if (first != null)
          Expanded(child: _PodiumColumn(entry: first, position: 1, height: 140))
        else
          const Spacer(),
        const SizedBox(width: AppSpacing.sm),
        if (third != null)
          Expanded(child: _PodiumColumn(entry: third, position: 3, height: 95))
        else
          const Spacer(),
      ],
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  const _PodiumColumn({
    required this.entry,
    required this.position,
    required this.height,
  });

  final CommunityLeaderboardEntry entry;
  final int position;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final isFirst = position == 1;

    final rankColor = switch (position) {
      1 => const Color(0xFFFFD700), // Gold
      2 => const Color(0xFFC0C0C0), // Silver
      3 => const Color(0xFFCD7F32), // Bronze
      _ => palette.primary,
    };

    final avatarSize = isFirst ? 64.0 : 52.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown/Rank badge on top
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: rankColor.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: rankColor, width: 1.5),
          ),
          child: Text(
            '#$position',
            style: AppTextStyles.labelSmall.copyWith(
              color: rankColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Avatar
        Container(
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: rankColor, width: 2),
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
        const SizedBox(height: 6),
        // Display Name
        Text(
          entry.displayName,
          style: AppTextStyles.labelMedium.copyWith(
            color: palette.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        // Level badge + points
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LevelBadge(level: entry.level),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '${entry.totalPoints} pts',
                style: AppTextStyles.labelSmall.copyWith(
                  color: palette.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // Podium pedestal bar
        Container(
          height: height,
          decoration: BoxDecoration(
            color: isFirst
                ? palette.primary.withValues(alpha: 0.15)
                : palette.cardHigh,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.md),
            ),
            border: Border.all(
              color: isFirst
                  ? palette.primary.withValues(alpha: 0.3)
                  : palette.border,
            ),
          ),
          child: Center(
            child: AppIcon(
              position == 1
                  ? AppIcons.celebrate
                  : (position == 2 ? AppIcons.medal : AppIcons.star),
              color: rankColor,
              size: isFirst ? 28 : 22,
            ),
          ),
        ),
      ],
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
