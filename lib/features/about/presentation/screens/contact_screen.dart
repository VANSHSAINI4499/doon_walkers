import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/about/presentation/widgets/community_links_section.dart';
import 'package:doon_walkers/features/about/presentation/widgets/settings_backed_page.dart';
import 'package:flutter/material.dart';

/// Contact — every channel the community publishes, from
/// `public.settings`.
///
/// The "Get in Touch" block that used to sit at the bottom of Home's
/// About section, now its own drawer destination.
///
/// See [SupportScreen] for the deliberate overlap between the two: this
/// page is the full directory, Support is the subset that reaches a
/// person.
class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) => SettingsBackedPage(
    title: 'Contact',
    builder: (context, settings) {
      final palette = AppPalette.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Reach the community',
            style: AppTextStyles.titleMedium.copyWith(
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Follow along, join the group chat, or get in touch directly.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          CommunityLinksSection(settings: settings),
        ],
      );
    },
  );
}
