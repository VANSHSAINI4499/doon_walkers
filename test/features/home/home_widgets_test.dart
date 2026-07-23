// Widget coverage for the Phase 2 Home rebuild. Scoped to the sections
// whose providers can be overridden without a live Supabase client
// (JoinCommunity/HomeAbout read Supabase.instance directly, so they're
// exercised via the live app, not here). The point of these tests is to
// pin the preserved behaviour: the hero shows the tagline, stats degrade
// softly on error, loading shows a skeleton (not a spinner), and empty
// About blocks stay hidden.

import 'dart:async';

import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/icons/app_icons.dart';
import 'package:doon_walkers/core/theme/app_theme.dart';
import 'package:doon_walkers/core/widgets/skeleton.dart';
import 'package:doon_walkers/features/home/domain/entities/community_stats.dart';
import 'package:doon_walkers/features/home/presentation/providers/community_stats_provider.dart';
import 'package:doon_walkers/features/home/presentation/widgets/about_text_section.dart';
import 'package:doon_walkers/features/home/presentation/widgets/community_stats_section.dart';
import 'package:doon_walkers/features/home/presentation/widgets/home_hero_header.dart';
import 'package:doon_walkers/features/home/presentation/widgets/trek_section_placeholder.dart';
import 'package:doon_walkers/features/settings/domain/entities/app_settings.dart';
import 'package:doon_walkers/features/settings/presentation/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    ),
  );
}

void main() {
  group('HomeHeroHeader', () {
    testWidgets('shows the org tagline from settings', (tester) async {
      await tester.pumpWidget(_host(
        const HomeHeroHeader(),
        overrides: [
          settingsProvider.overrideWith(
            (ref) => const AppSettings({'org_tagline': 'Wander the wild Himalaya'}),
          ),
        ],
      ));
      await tester.pump();
      expect(find.text('Wander the wild Himalaya'), findsOneWidget);
    });

    testWidgets('falls back to the constant tagline when settings are blank',
        (tester) async {
      await tester.pumpWidget(_host(
        const HomeHeroHeader(),
        overrides: [
          settingsProvider.overrideWith((ref) => const AppSettings({'org_tagline': ''})),
        ],
      ));
      await tester.pump();
      expect(find.text(AppConstants.appTagline), findsOneWidget);
    });
  });

  group('CommunityStatsSection', () {
    testWidgets('shows a skeleton (not a spinner) while loading', (tester) async {
      await tester.pumpWidget(_host(
        const CommunityStatsSection(),
        overrides: [
          communityStatsProvider.overrideWith((ref) => Completer<CommunityStats>().future),
        ],
      ));
      await tester.pump();
      expect(find.byType(Shimmer), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('renders the real numbers on data', (tester) async {
      await tester.pumpWidget(_host(
        const CommunityStatsSection(),
        overrides: [
          communityStatsProvider.overrideWith(
            (ref) => const CommunityStats(
              memberCount: 42,
              publishedTrekCount: 7,
              registrationCount: 15,
            ),
          ),
        ],
      ));
      // Let the count-up animation settle onto the exact values.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('42'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
    });

    testWidgets('softens a fetch failure to zeros + a notice', (tester) async {
      await tester.pumpWidget(_host(
        const CommunityStatsSection(),
        overrides: [
          communityStatsProvider.overrideWith((ref) => Future.error('boom')),
        ],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Stats unavailable right now.'), findsOneWidget);
      expect(find.text('0'), findsNWidgets(3));
    });
  });

  group('TrekSectionPlaceholder', () {
    testWidgets('renders its message and icon', (tester) async {
      await tester.pumpWidget(_host(
        const TrekSectionPlaceholder(
          icon: AppIcons.hiking,
          message: 'No upcoming treks scheduled yet — check back soon!',
        ),
      ));
      await tester.pump();
      expect(
        find.text('No upcoming treks scheduled yet — check back soon!'),
        findsOneWidget,
      );
      expect(find.byType(AppIcon), findsWidgets);
    });
  });

  group('AboutTextSection', () {
    testWidgets('renders nothing when the body is empty', (tester) async {
      await tester.pumpWidget(_host(
        const AboutTextSection(title: 'Our Story', icon: AppIcons.book, body: '   '),
      ));
      await tester.pump();
      expect(find.text('Our Story'), findsNothing);
    });

    testWidgets('renders the block when the body has content', (tester) async {
      await tester.pumpWidget(_host(
        const AboutTextSection(
          title: 'Our Story',
          icon: AppIcons.book,
          body: 'We started with five friends and a shared trailhead.',
        ),
      ));
      await tester.pump();
      expect(find.text('Our Story'), findsOneWidget);
      expect(
        find.text('We started with five friends and a shared trailhead.'),
        findsOneWidget,
      );
    });
  });
}
