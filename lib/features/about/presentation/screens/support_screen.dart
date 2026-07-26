import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/about/presentation/widgets/about_text_section.dart';
import 'package:doon_walkers/features/about/presentation/widgets/community_links_section.dart';
import 'package:doon_walkers/features/about/presentation/widgets/settings_backed_page.dart';
import 'package:flutter/material.dart';

/// Support — how to get help.
///
/// ## The overlap with Contact, stated plainly
///
/// Both entries were specified for the drawer, and the app has exactly
/// one pool of contact data in `public.settings` and no ticketing or
/// help-desk backend. So these two pages necessarily draw on the same
/// rows. They are not identical, but they are close:
///
///  - **Contact** lists every channel, Instagram included — it is the
///    community's public directory.
///  - **Support** (here) shows only the channels that reach a person who
///    can actually answer a question (WhatsApp, email, phone), and pairs
///    them with the community rules, which is what most "how does this
///    work" questions are really asking about.
///
/// **Recommendation:** if the distinction does not earn its place once
/// this is in front of real members, drop Support and keep Contact — a
/// second drawer entry to near-identical content costs more in confusion
/// than it returns. Merging them is a two-line change to the drawer.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) => SettingsBackedPage(
    title: 'Support',
    builder: (context, settings) {
      final palette = AppPalette.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Need a hand?',
            style: AppTextStyles.titleMedium.copyWith(
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Message us on any of these and someone from the community '
            'will get back to you.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          CommunityLinksSection(
            settings: settings,
            filter: CommunityLinkFilter.supportOnly,
            emptyMessage:
                'Support channels are being set up. Check back shortly.',
          ),
          const SizedBox(height: AppSpacing.xxl),
          AboutTextSection(
            title: 'Community Rules',
            icon: AppIcons.rule,
            body: settings.communityRules,
          ),
        ],
      );
    },
  );
}
