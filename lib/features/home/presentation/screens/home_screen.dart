import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/home/presentation/widgets/community_stats_section.dart';
import 'package:doon_walkers/features/home/presentation/widgets/home_about_section.dart';
import 'package:doon_walkers/features/home/presentation/widgets/home_hero_header.dart';
import 'package:doon_walkers/features/home/presentation/widgets/home_section_header.dart';
import 'package:doon_walkers/features/home/presentation/widgets/join_community_section.dart';
import 'package:flutter/material.dart';

/// The Home tab.
///
/// Redesign Phase 2: rebuilt entirely on the Phase 1 design system.
/// Content since then:
///   - Hero greeting: tagline from settings (unchanged).
///   - Community stats: `get_community_stats()` (unchanged; the Home
///     content pass removed the Signups tile and bucketed the member
///     count — see CommunityStatsSection's own doc).
///   - The "Upcoming Trek"/"Featured Trek"/"Recent Memories" placeholder
///     blocks (never backed by real data) were removed outright in that
///     same pass — upcoming treks already sort to the top of the Treks
///     tab, and the other two weren't wanted at all.
///   - Join Community: guest-only now (see its own doc) + About:
///     unchanged settings logic.
///
/// Assembly notes: the hero is full-bleed (outside the reading-width
/// clamp); everything below sits in a 720dp-max column so the screen
/// stays comfortable on tablets and web. Sections fade-and-rise in on a
/// gentle stagger via [AppReveal] — polish, not spectacle.
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
      const JoinCommunitySection(),
      const _AboutDivider(),
      // About content — folded in here now that the standalone About
      // screen/tab is gone (Part B of the navigation restructure).
      const HomeAboutSection(),
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

class _AboutDivider extends StatelessWidget {
  const _AboutDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.huge),
      child: Divider(),
    );
  }
}
