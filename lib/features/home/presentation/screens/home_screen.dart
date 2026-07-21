import 'package:doon_walkers/core/widgets/section_header.dart';
import 'package:doon_walkers/features/home/presentation/widgets/community_stats_section.dart';
import 'package:doon_walkers/features/home/presentation/widgets/home_about_section.dart';
import 'package:doon_walkers/features/home/presentation/widgets/home_hero_header.dart';
import 'package:doon_walkers/features/home/presentation/widgets/join_community_section.dart';
import 'package:doon_walkers/features/home/presentation/widgets/trek_section_placeholder.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const HomeHeroHeader(),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionHeader(
                          title: 'Community at a Glance',
                          icon: Icons.insights_rounded,
                        ),
                        SizedBox(height: 12),
                        CommunityStatsSection(),
                        SizedBox(height: 28),

                        SectionHeader(
                          title: 'Upcoming Trek',
                          icon: Icons.event_outlined,
                        ),
                        SizedBox(height: 12),
                        TrekSectionPlaceholder(
                          icon: Icons.hiking_rounded,
                          message:
                              'No upcoming treks scheduled yet — check back soon!',
                        ),
                        SizedBox(height: 28),

                        SectionHeader(
                          title: 'Featured Trek',
                          icon: Icons.star_border_rounded,
                        ),
                        SizedBox(height: 12),
                        TrekSectionPlaceholder(
                          icon: Icons.landscape_outlined,
                          message:
                              'Our trek library is being built — featured treks will appear here.',
                        ),
                        SizedBox(height: 28),

                        SectionHeader(
                          title: 'Recent Memories',
                          icon: Icons.photo_library_outlined,
                        ),
                        SizedBox(height: 12),
                        TrekSectionPlaceholder(
                          icon: Icons.photo_camera_back_outlined,
                          message:
                              'Trip photos and videos will show up here once the gallery goes live.',
                        ),
                        SizedBox(height: 28),

                        JoinCommunitySection(),
                        SizedBox(height: 32),

                        Divider(),
                        SizedBox(height: 24),

                        // About content — folded in here now that the
                        // standalone About screen/tab is gone (Part B of
                        // the navigation restructure); see HomeAboutSection.
                        HomeAboutSection(),
                        SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
