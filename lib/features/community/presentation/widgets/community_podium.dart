import 'package:cached_network_image/cached_network_image.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/level_badge.dart';
import 'package:doon_walkers/features/community/domain/entities/community_leaderboard_entry.dart';
import 'package:flutter/material.dart';

/// A premium 3-step podium with staggered reveal animation.
///
/// Rank #1 stands tallest in the centre, #2 left, #3 right — the classic
/// medal-ceremony arrangement. The pedestal bars show the rank number in
/// a large, semi-transparent watermark so the position reads at a glance.
/// #1 gets a gold gradient pedestal; #2 and #3 get muted metallic fills.
///
/// Each column slides up from below on first appearance using
/// [AnimatedSlide] + [AnimatedOpacity], staggered so they land in order
/// (2 → 1 → 3) for a natural reveal rhythm.
class CommunityPodium extends StatefulWidget {
  const CommunityPodium({super.key, required this.entries});

  /// Up to 3 top entries.
  final List<CommunityLeaderboardEntry> entries;

  @override
  State<CommunityPodium> createState() => _CommunityPodiumState();
}

class _CommunityPodiumState extends State<CommunityPodium>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) return const SizedBox.shrink();

    final first = widget.entries.isNotEmpty ? widget.entries[0] : null;
    final second = widget.entries.length > 1 ? widget.entries[1] : null;
    final third = widget.entries.length > 2 ? widget.entries[2] : null;

    // Staggered delay: #2 (0ms), #1 (80ms), #3 (160ms)
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (second != null)
          Expanded(
            child: _AnimatedPodiumColumn(
              controller: _controller,
              delay: 0.0,
              child: _PodiumColumn(entry: second, position: 2, height: 110),
            ),
          )
        else
          const Spacer(),
        const SizedBox(width: AppSpacing.sm),
        if (first != null)
          Expanded(
            child: _AnimatedPodiumColumn(
              controller: _controller,
              delay: 0.15,
              child: _PodiumColumn(entry: first, position: 1, height: 145),
            ),
          )
        else
          const Spacer(),
        const SizedBox(width: AppSpacing.sm),
        if (third != null)
          Expanded(
            child: _AnimatedPodiumColumn(
              controller: _controller,
              delay: 0.30,
              child: _PodiumColumn(entry: third, position: 3, height: 90),
            ),
          )
        else
          const Spacer(),
      ],
    );
  }
}

class _AnimatedPodiumColumn extends StatelessWidget {
  const _AnimatedPodiumColumn({
    required this.controller,
    required this.delay,
    required this.child,
  });

  final AnimationController controller;
  final double delay; // 0.0–1.0 fraction of total duration
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delayedStart = delay;
    final delayedEnd = (delay + 0.7).clamp(0.0, 1.0);

    final slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(delayedStart, delayedEnd, curve: Curves.easeOutCubic),
      ),
    );

    final fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(delayedStart, delayedEnd, curve: Curves.easeIn),
      ),
    );

    return FadeTransition(
      opacity: fadeAnim,
      child: SlideTransition(position: slideAnim, child: child),
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

    // Rank medal colours
    final rankColor = switch (position) {
      1 => const Color(0xFFFFD700), // Gold
      2 => const Color(0xFFC0C0C0), // Silver
      3 => const Color(0xFFCD7F32), // Bronze
      _ => palette.primary,
    };

    // Avatar size: slightly larger for #1
    final avatarSize = isFirst ? 64.0 : 52.0;

    // Pedestal gradient for #1 (gold-tinted), muted metallic for #2/#3
    final pedestalDecoration =
        isFirst
            ? BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  rankColor.withValues(alpha: 0.25),
                  rankColor.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.md),
              ),
              border: Border.all(
                color: rankColor.withValues(alpha: 0.5),
                width: 1.5,
              ),
            )
            : BoxDecoration(
              color: palette.cardHigh,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.md),
              ),
              border: Border.all(color: palette.border),
            );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown icon above #1
        if (isFirst) ...[
          AppIcon(AppIcons.celebrate, color: rankColor, size: 20),
          const SizedBox(height: 4),
        ],

        // Rank medal badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: rankColor.withValues(alpha: 0.18),
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

        // Avatar with rank-coloured ring
        Container(
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: rankColor, width: isFirst ? 2.5 : 2),
            color: palette.primarySubtle,
          ),
          child: ClipOval(
            child:
                entry.avatarUrl != null && entry.avatarUrl!.isNotEmpty
                    ? CachedNetworkImage(
                      imageUrl: entry.avatarUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _Initials(entry.displayName),
                    )
                    : _Initials(entry.displayName),
          ),
        ),
        const SizedBox(height: 6),

        // Display name
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

        // Pedestal bar with large watermark rank number
        Container(
          height: height,
          decoration: pedestalDecoration,
          clipBehavior: Clip.antiAlias,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Watermark rank number
              Text(
                '#$position',
                style: TextStyle(
                  fontSize: height * 0.55,
                  fontWeight: FontWeight.w900,
                  color: rankColor.withValues(alpha: 0.12),
                  height: 1,
                ),
              ),
              // Centred icon on top of watermark
              AppIcon(
                position == 1
                    ? AppIcons.medal
                    : (position == 2 ? AppIcons.medal : AppIcons.star),
                color: rankColor.withValues(alpha: 0.5),
                size: isFirst ? 28 : 22,
              ),
            ],
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
