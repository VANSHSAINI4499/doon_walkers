import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/registrations/presentation/providers/registration_providers.dart';
import 'package:doon_walkers/features/registrations/presentation/widgets/registration_tile.dart';
import 'package:doon_walkers/features/trek_library/presentation/providers/trek_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// One trek's registered members only — reached by tapping a trek on
/// [AdminTrekPickerScreen]. Shows name, phone, email, registration date
/// and status, via the shared [RegistrationTile] with the trek-title
/// row suppressed (it's already this screen's AppBar title).
///
/// Reuses [registrationsForTrekProvider], which reuses
/// [RegistrationRepository] with a `.eq('trek_id', ...)` filter — no
/// parallel registrations implementation for this screen.
class AdminTrekRegistrationsScreen extends ConsumerWidget {
  const AdminTrekRegistrationsScreen({super.key, required this.trekId});

  final String trekId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final trekAsync = ref.watch(trekByIdProvider(trekId));
    final registrationsAsync = ref.watch(registrationsForTrekProvider(trekId));

    return Scaffold(
      appBar: AppBar(
        title: trekAsync.maybeWhen(
          data: (trek) => Text(trek?.title ?? 'Trek Registrations'),
          orElse: () => const Text('Trek Registrations'),
        ),
      ),
      body: SafeArea(
        child: registrationsAsync.when(
          loading: () => const _TrekRegistrationsSkeleton(),
          error: (error, stack) {
            debugPrint('AdminTrekRegistrationsScreen: failed to load registrations: $error');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(AppIcons.error, size: 40, color: palette.danger),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Could not load registrations for this trek.',
                      style: AppTextStyles.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PremiumButton(
                      label: 'Retry',
                      icon: AppIcons.refresh,
                      variant: PremiumButtonVariant.glass,
                      size: PremiumButtonSize.small,
                      onPressed: () => ref.invalidate(registrationsForTrekProvider(trekId)),
                    ),
                  ],
                ),
              ),
            );
          },
          data: (registrations) {
            Future<void> onRefresh() =>
                ref.refresh(registrationsForTrekProvider(trekId).future);

            if (registrations.isEmpty) {
              return RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [_EmptyTrekRegistrations()],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
                itemCount: registrations.length,
                separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final registration = registrations[index];
                  return AppReveal(
                    index: index.clamp(0, 8),
                    child: RegistrationTile(
                      registration: registration,
                      showTrekTitle: false,
                      // Nested under THIS tab's own branch, not
                      // adminRegistrationDetailLocation — see that
                      // constant's doc for why pushing the flat roster's
                      // path here would switch tabs and misplace "back".
                      onTap: () => context.push(
                        AppConstants.adminTrekRegistrationsDetailLocation(
                          trekId,
                          registration.id,
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyTrekRegistrations extends StatelessWidget {
  const _EmptyTrekRegistrations();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: palette.primarySubtle,
              shape: BoxShape.circle,
              border: Border.all(color: palette.primary.withValues(alpha: 0.3)),
            ),
            child: AppIcon(AppIcons.registrations, size: 48, color: palette.primary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'No registrations yet',
            style: AppTextStyles.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Members who register for this trek will show up here.',
            style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TrekRegistrationsSkeleton extends StatelessWidget {
  const _TrekRegistrationsSkeleton();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Shimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: 4,
        separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) => Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: palette.border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 180, height: 16),
              SizedBox(height: AppSpacing.sm),
              SkeletonBox(width: 140, height: 10),
              SizedBox(height: AppSpacing.md),
              SkeletonBox(width: 220, height: 44, borderRadius: AppRadius.sm),
            ],
          ),
        ),
      ),
    );
  }
}
