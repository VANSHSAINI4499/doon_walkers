import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/about/presentation/widgets/about_text_section.dart';
import 'package:doon_walkers/features/about/presentation/widgets/settings_backed_page.dart';
import 'package:flutter/material.dart';

/// About — org identity plus the community's prose blocks (Our Story,
/// Founder's Message, Vision, Mission, Rules, Why Join Us), all sourced
/// from `public.settings`.
///
/// ## Why this is no longer on Home
///
/// This content used to be appended to the bottom of Home as
/// `HomeAboutSection`. Phase 10 moved it here **wholly** rather than
/// duplicating it, for three reasons:
///
///  1. The calm direction asks every screen to have one primary purpose.
///     Six long prose blocks below Home's stats and links made Home's
///     purpose "everything", which is the opposite.
///  2. It is read-once content on the app's most-returned-to screen.
///     Whatever a member opens Home for, it is not the founder's message
///     for the fortieth time.
///  3. Duplicating it would mean two code paths over one settings fetch,
///     drifting apart the first time either is restyled.
///
/// Contact links deliberately do **not** appear here — they are their own
/// drawer destination now ([routeContact]), so this page is About and
/// nothing else.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) => SettingsBackedPage(
    title: 'About',
    builder: (context, settings) {
      final orgName = settings.orgName.isEmpty
          ? AppConstants.orgName
          : settings.orgName;
      final orgCity = settings.orgCity.isEmpty
          ? AppConstants.orgCity
          : settings.orgCity;
      final orgState = settings.orgState.isEmpty
          ? AppConstants.orgState
          : settings.orgState;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OrgIdentity(name: orgName, city: orgCity, state: orgState),
          const SizedBox(height: AppSpacing.xxl),
          AboutTextSection(
            title: 'Our Story',
            icon: AppIcons.book,
            body: settings.communityStory,
          ),
          AboutTextSection(
            title: "Founder's Message",
            icon: AppIcons.speaker,
            body: settings.founderMessage,
          ),
          AboutTextSection(
            title: 'Our Vision',
            icon: AppIcons.visible,
            body: settings.vision,
          ),
          AboutTextSection(
            title: 'Our Mission',
            icon: AppIcons.flag,
            body: settings.mission,
          ),
          AboutTextSection(
            title: 'Community Rules',
            icon: AppIcons.rule,
            body: settings.communityRules,
          ),
          AboutTextSection(
            title: 'Why Join Us',
            icon: AppIcons.favorite,
            body: settings.whyJoin,
          ),
        ],
      );
    },
  );
}

class _OrgIdentity extends StatelessWidget {
  const _OrgIdentity({
    required this.name,
    required this.city,
    required this.state,
  });

  final String name;
  final String city;
  final String state;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: palette.primary,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: AppIcon(
            AppIcons.landscape,
            size: 36,
            color: palette.onPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          name,
          textAlign: TextAlign.center,
          style: AppTextStyles.headlineSmall.copyWith(
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(AppIcons.map, size: 16, color: palette.textSecondary),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '$city, $state',
              style: AppTextStyles.bodyMedium.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
