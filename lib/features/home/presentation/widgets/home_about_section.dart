import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/home/presentation/widgets/about_text_section.dart';
import 'package:doon_walkers/features/home/presentation/widgets/community_links_section.dart';
import 'package:doon_walkers/features/home/presentation/widgets/home_section_header.dart';
import 'package:doon_walkers/features/settings/presentation/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "About" content — org identity, Our Story / Founder's Message / Vision
/// / Mission / Community Rules / Why Join Us, and contact links — folded
/// into Home below its other sections.
///
/// Unchanged behaviour: self-contained watch of [settingsProvider] (same
/// convention as the other sections), the org name/city/state fall back
/// to [AppConstants] when a settings row is blank, each prose block hides
/// itself when empty (see [AboutTextSection]), and a load failure shows a
/// retry. Restyled onto glass, with a skeleton (not a spinner) while
/// loading and a [PremiumButton] retry.
class HomeAboutSection extends ConsumerWidget {
  const HomeAboutSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return settingsAsync.when(
      loading: () => const _AboutSkeleton(),
      error: (error, stack) {
        debugPrint('HomeAboutSection: failed to load settings: $error');
        return GlassCard(
          blurEnabled: false,
          glowColor: AppColors.danger,
          glowOpacity: 0.12,
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppIcon(AppIcons.error, size: 40, color: AppColors.danger),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Could not load community info.',
                style: AppTextStyles.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              PremiumButton(
                label: 'Retry',
                icon: AppIcons.refresh,
                variant: PremiumButtonVariant.glass,
                size: PremiumButtonSize.small,
                onPressed: () => ref.invalidate(settingsProvider),
              ),
            ],
          ),
        );
      },
      data: (settings) {
        final orgName = settings.orgName.isEmpty ? AppConstants.orgName : settings.orgName;
        final orgCity = settings.orgCity.isEmpty ? AppConstants.orgCity : settings.orgCity;
        final orgState = settings.orgState.isEmpty ? AppConstants.orgState : settings.orgState;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OrgIdentity(name: orgName, city: orgCity, state: orgState),
            const SizedBox(height: AppSpacing.xxl),

            AboutTextSection(
              title: 'Our Story',
              icon: AppIcons.book,
              body: settings.communityStory,
              accent: AppColors.primary,
            ),
            AboutTextSection(
              title: "Founder's Message",
              icon: AppIcons.speaker,
              body: settings.founderMessage,
              accent: AppColors.secondary,
            ),
            AboutTextSection(
              title: 'Our Vision',
              icon: AppIcons.visible,
              body: settings.vision,
              accent: AppColors.accent,
            ),
            AboutTextSection(
              title: 'Our Mission',
              icon: AppIcons.flag,
              body: settings.mission,
              accent: AppColors.gold,
            ),
            AboutTextSection(
              title: 'Community Rules',
              icon: AppIcons.rule,
              body: settings.communityRules,
              accent: AppColors.primary,
            ),
            AboutTextSection(
              title: 'Why Join Us',
              icon: AppIcons.favorite,
              body: settings.whyJoin,
              accent: AppColors.danger,
            ),

            const HomeSectionHeader(
              title: 'Get in Touch',
              icon: AppIcons.connect,
              accent: AppColors.secondary,
            ),
            const SizedBox(height: AppSpacing.md),
            CommunityLinksSection(settings: settings),
          ],
        );
      },
    );
  }
}

class _OrgIdentity extends StatelessWidget {
  const _OrgIdentity({required this.name, required this.city, required this.state});

  final String name;
  final String city;
  final String state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: AppGradients.primary,
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: AppShadows.glow(AppColors.primary, opacity: 0.35),
          ),
          child: const AppIcon(
            AppIcons.landscape,
            size: 40,
            color: AppColors.onPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          name,
          textAlign: TextAlign.center,
          style: AppTextStyles.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppIcon(
              AppIcons.map,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '$city, $state',
              style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
            ),
          ],
        ),
      ],
    );
  }
}

class _AboutSkeleton extends StatelessWidget {
  const _AboutSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Shimmer(
          child: Column(
            children: [
              SkeletonBox(width: 72, height: 72, borderRadius: AppRadius.card),
              SizedBox(height: AppSpacing.lg),
              SkeletonBox(width: 160, height: 22),
              SizedBox(height: AppSpacing.sm),
              SkeletonBox(width: 120, height: 12),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.xxl),
        SkeletonList(count: 2, showImages: false),
      ],
    );
  }
}
