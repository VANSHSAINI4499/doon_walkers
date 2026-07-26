import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/home/presentation/widgets/community_stats_section.dart';
import 'package:doon_walkers/features/home/presentation/widgets/home_hero_header.dart';
import 'package:doon_walkers/features/home/presentation/widgets/home_section_header.dart';
import 'package:doon_walkers/features/home/presentation/widgets/join_community_section.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The Home tab.
///
/// Redesign Phase 2: rebuilt entirely on the Phase 1 design system.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const HomeHeroHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: const _HomeBody(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    // Each entry is one staggered section; index drives the entrance delay.
    final sections = <Widget>[
      const _Section(
        header: HomeSectionHeader(
          title: 'Community at a Glance',
          icon: AppIcons.insights,
          accent: AppColors.primary,
        ),
        child: CommunityStatsSection(),
      ),
      const _ChallengesQuickCard(),
      const JoinCommunitySection(),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sections.length; i++)
          AppReveal(
            index: i,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: i == sections.length - 1 ? 0 : AppSpacing.xxxl,
              ),
              child: sections[i],
            ),
          ),
      ],
    );
  }
}

/// A header + its content, with the standard gap between them.
class _Section extends StatelessWidget {
  const _Section({required this.header, required this.child});

  final Widget header;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    );
  }
}

class _ChallengesQuickCard extends StatelessWidget {
  const _ChallengesQuickCard();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return AppCard(
      onTap: () => context.push(AppConstants.routeChallenges),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: palette.primarySubtle,
              shape: BoxShape.circle,
            ),
            child: AppIcon(AppIcons.challenges, size: 24, color: palette.primary),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Explore Challenges', style: AppTextStyles.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'Join community challenges and earn streak badges.',
                  style: AppTextStyles.secondary(AppTextStyles.bodySmall),
                ),
              ],
            ),
          ),
          AppIcon(AppIcons.chevronRight, color: palette.textSecondary),
        ],
      ),
    );
  }
}

