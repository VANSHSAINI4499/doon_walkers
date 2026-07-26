import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The Community tab — sub-tabs for Feed, Members, and Leaderboard.
///
/// Features three calm coming-soon placeholders built with [AppCard] and
/// [AppPalette]. The Leaderboard sub-tab includes a prominent action
/// button directing users to the full Challenges experience.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  int _selectedSubTab = 0; // 0: Feed, 1: Members, 2: Leaderboard

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Segmented sub-tab control
              _SubTabSegmentedControl(
                selectedIndex: _selectedSubTab,
                onSelected: (index) => setState(() => _selectedSubTab = index),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Active sub-tab content
              AnimatedSwitcher(
                duration: AppMotion.medium,
                switchInCurve: AppMotion.standard,
                child: KeyedSubtree(
                  key: ValueKey(_selectedSubTab),
                  child: _buildSubTabContent(context, palette),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubTabContent(BuildContext context, AppPalette palette) {
    switch (_selectedSubTab) {
      case 0:
        return const _FeedPlaceholder();
      case 1:
        return const _MembersPlaceholder();
      case 2:
        return const _LeaderboardPlaceholder();
      default:
        return const SizedBox.shrink();
    }
  }
}

class _SubTabSegmentedControl extends StatelessWidget {
  const _SubTabSegmentedControl({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final labels = ['Feed', 'Members', 'Leaderboard'];

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Pressable(
                onTap: () => onSelected(i),
                child: AnimatedContainer(
                  duration: AppMotion.medium,
                  curve: AppMotion.standard,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: i == selectedIndex ? palette.primarySubtle : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: i == selectedIndex
                        ? AppTextStyles.tinted(AppTextStyles.labelMedium, palette.primary)
                        : AppTextStyles.secondary(AppTextStyles.labelMedium),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeedPlaceholder extends StatelessWidget {
  const _FeedPlaceholder();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: palette.primarySubtle,
              shape: BoxShape.circle,
              border: Border.all(color: palette.primary.withValues(alpha: 0.3)),
            ),
            child: AppIcon(AppIcons.forum, size: 36, color: palette.primary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Community stories are coming soon.',
            style: AppTextStyles.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Share trail logs, trip photos, and outdoor experiences with fellow trekkers.',
            style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MembersPlaceholder extends StatelessWidget {
  const _MembersPlaceholder();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: palette.primarySubtle,
              shape: BoxShape.circle,
              border: Border.all(color: palette.primary.withValues(alpha: 0.3)),
            ),
            child: AppIcon(AppIcons.group, size: 36, color: palette.primary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Meet your fellow Doon Walkers — coming soon.',
            style: AppTextStyles.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Connect with local guides, experienced hikers, and community leads.',
            style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LeaderboardPlaceholder extends StatelessWidget {
  const _LeaderboardPlaceholder();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: palette.primarySubtle,
              shape: BoxShape.circle,
              border: Border.all(color: palette.primary.withValues(alpha: 0.3)),
            ),
            child: AppIcon(AppIcons.leaderboard, size: 36, color: palette.primary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'See how you stack up — coming soon.',
            style: AppTextStyles.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Community rankings and monthly challenge leaderboards are right around the corner.',
            style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          PremiumButton(
            label: 'View Challenges',
            icon: AppIcons.challenges,
            onPressed: () => context.push(AppConstants.routeChallenges),
          ),
        ],
      ),
    );
  }
}
