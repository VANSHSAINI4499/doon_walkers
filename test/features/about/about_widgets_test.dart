// Coverage for the About-feature widgets, moved here from
// test/features/home/ when Redesign 2.0 Phase 10 pulled About out of Home
// into its own drawer destination.
//
// The "hides itself when the settings row is blank" behaviour is the
// important one: every one of these prose blocks is optional data
// entered via the Supabase dashboard, so a blank row must disappear
// rather than render an empty card.

import 'package:doon_walkers/core/icons/app_icons.dart';
import 'package:doon_walkers/core/theme/app_theme.dart';
import 'package:doon_walkers/features/about/presentation/widgets/about_text_section.dart';
import 'package:doon_walkers/features/about/presentation/widgets/community_links_section.dart';
import 'package:doon_walkers/features/settings/domain/entities/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.dark,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  group('AboutTextSection', () {
    testWidgets('renders nothing when the body is empty', (tester) async {
      await tester.pumpWidget(
        _host(
          const AboutTextSection(
            title: 'Our Story',
            icon: AppIcons.book,
            body: '   ',
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Our Story'), findsNothing);
    });

    testWidgets('renders the block when the body has content', (tester) async {
      await tester.pumpWidget(
        _host(
          const AboutTextSection(
            title: 'Our Story',
            icon: AppIcons.book,
            body: 'We started with five friends and a shared trailhead.',
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Our Story'), findsOneWidget);
      expect(
        find.text('We started with five friends and a shared trailhead.'),
        findsOneWidget,
      );
    });

    testWidgets('renders in light theme too', (tester) async {
      await tester.pumpWidget(
        _host(
          const AboutTextSection(
            title: 'Our Vision',
            icon: AppIcons.visible,
            body: 'Walk more, together.',
          ),
          theme: AppTheme.light,
        ),
      );
      await tester.pump();
      expect(find.text('Our Vision'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('CommunityLinksSection', () {
    const allChannels = AppSettings({
      'instagram_url': 'https://instagram.com/doonwalkers',
      'whatsapp_url': 'https://chat.whatsapp.com/abc',
      'contact_email': 'hello@doonwalkers.test',
      'contact_phone': '+911234567890',
    });

    testWidgets('renders every channel that has a value', (tester) async {
      await tester.pumpWidget(
        _host(const CommunityLinksSection(settings: allChannels)),
      );
      await tester.pump();
      expect(find.text('Instagram'), findsOneWidget);
      expect(find.text('WhatsApp Group'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Phone'), findsOneWidget);
    });

    testWidgets('omits a channel whose settings row is blank', (tester) async {
      await tester.pumpWidget(
        _host(
          const CommunityLinksSection(
            settings: AppSettings({'contact_email': 'hello@doonwalkers.test'}),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Instagram'), findsNothing);
      expect(find.text('Phone'), findsNothing);
    });

    testWidgets('shows the empty state when nothing is configured', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const CommunityLinksSection(settings: AppSettings.empty)),
      );
      await tester.pump();
      expect(find.text('Contact details coming soon.'), findsOneWidget);
    });

    testWidgets('supportOnly drops Instagram but keeps the reachable ones', (
      tester,
    ) async {
      // Support is about reaching a person — a photo feed is not that.
      await tester.pumpWidget(
        _host(
          const CommunityLinksSection(
            settings: allChannels,
            filter: CommunityLinkFilter.supportOnly,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Instagram'), findsNothing);
      expect(find.text('WhatsApp Group'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Phone'), findsOneWidget);
    });

    testWidgets('supportOnly uses its own empty message', (tester) async {
      await tester.pumpWidget(
        _host(
          const CommunityLinksSection(
            settings: AppSettings({'instagram_url': 'https://instagram.com/x'}),
            filter: CommunityLinkFilter.supportOnly,
            emptyMessage: 'Support channels are being set up.',
          ),
        ),
      );
      await tester.pump();
      // Instagram is the only configured channel and supportOnly excludes
      // it, so this must fall through to the empty state rather than
      // rendering an empty card.
      expect(find.text('Support channels are being set up.'), findsOneWidget);
    });
  });
}
