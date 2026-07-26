import 'package:doon_walkers/core/design_system.dart';
import 'package:flutter/material.dart';

/// The Activity tab — **placeholder for Phase 10**.
///
/// Redesign 2.0 splits the work: Phase 10 (navigation) creates the tab,
/// the branch and the route so the destination genuinely exists and
/// navigates correctly; Phase 11 fills in the real Day / Week / Month
/// movement content on top of the activity data the app already syncs
/// (see `activity_providers.dart` — the repository, sync service and
/// Health Connect plumbing are all already built and running).
///
/// It is deliberately a *named, honest* placeholder rather than the
/// generic `ComingSoonScreen`: this tab is permanent and its content is
/// already scheduled, so it says what is coming here specifically instead
/// of implying an unbuilt feature of unknown fate.
///
/// It reads no data and touches no providers on purpose — wiring it to
/// `activityProviders` now would mean building (and then rebuilding)
/// Phase 11's data layer twice.
class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: palette.primarySubtle,
                  shape: BoxShape.circle,
                ),
                child: AppIcon(
                  AppIcons.steps,
                  size: 32,
                  color: palette.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Your activity',
                style: AppTextStyles.headlineSmall.copyWith(
                  color: palette.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Steps, distance and your walking streak — day, week and '
                'month — are landing here next.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: palette.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              // A muted preview of the shape the real screen will take,
              // so the placeholder reads as "not built yet" rather than
              // "broken". Static by design — no data behind it.
              AppCard(
                child: Column(
                  children: [
                    StatDisplay(
                      value: '—',
                      eyebrow: 'Today',
                      label: 'steps',
                      size: StatSize.hero,
                      color: palette.textDisabled,
                      alignment: CrossAxisAlignment.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppProgressBar(
                      value: 0,
                      label: 'Daily goal',
                      trailing: '—',
                      color: palette.textDisabled,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
