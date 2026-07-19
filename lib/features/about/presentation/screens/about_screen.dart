import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/widgets/section_header.dart';
import 'package:doon_walkers/features/about/presentation/widgets/about_text_section.dart';
import 'package:doon_walkers/features/about/presentation/widgets/community_links_section.dart';
import 'package:doon_walkers/features/settings/presentation/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('About Doon Walkers')),
      body: SafeArea(
        child: settingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 40,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Could not load community info.',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => ref.invalidate(settingsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (settings) {
            final orgName = settings.orgName.isEmpty ? AppConstants.orgName : settings.orgName;
            final orgCity = settings.orgCity.isEmpty ? AppConstants.orgCity : settings.orgCity;
            final orgState = settings.orgState.isEmpty ? AppConstants.orgState : settings.orgState;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.landscape_rounded,
                        size: 56,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        orgName,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$orgCity, $orgState',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),

                      AboutTextSection(
                        title: 'Our Story',
                        icon: Icons.menu_book_outlined,
                        body: settings.communityStory,
                      ),
                      AboutTextSection(
                        title: "Founder's Message",
                        icon: Icons.record_voice_over_outlined,
                        body: settings.founderMessage,
                      ),
                      AboutTextSection(
                        title: 'Our Vision',
                        icon: Icons.visibility_outlined,
                        body: settings.vision,
                      ),
                      AboutTextSection(
                        title: 'Our Mission',
                        icon: Icons.flag_outlined,
                        body: settings.mission,
                      ),
                      AboutTextSection(
                        title: 'Community Rules',
                        icon: Icons.rule_outlined,
                        body: settings.communityRules,
                      ),
                      AboutTextSection(
                        title: 'Why Join Us',
                        icon: Icons.favorite_outline,
                        body: settings.whyJoin,
                      ),

                      const SectionHeader(
                        title: 'Get in Touch',
                        icon: Icons.connect_without_contact_outlined,
                      ),
                      const SizedBox(height: 12),
                      CommunityLinksSection(settings: settings),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
