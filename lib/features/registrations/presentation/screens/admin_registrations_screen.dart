import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/registrations/presentation/providers/registration_providers.dart';
import 'package:doon_walkers/features/registrations/presentation/widgets/registration_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Admin registrations roster — every registration across every trek.
///
/// Kept as its own Admin Dashboard destination rather than inlined into a
/// trek screen (unlike trek/gallery CRUD): a cross-trek roster has no
/// single-trek screen it naturally belongs to.
///
/// Reachable only via the admin-gated `/admin/registrations` route;
/// `registrations_select` backs that up independently by returning only
/// the caller's own rows to a non-admin.
class AdminRegistrationsScreen extends ConsumerWidget {
  const AdminRegistrationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final registrationsAsync = ref.watch(allRegistrationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Registrations')),
      body: SafeArea(
        child: registrationsAsync.when(
          loading: () => const _RegistrationsSkeleton(),
          error: (error, stack) {
            debugPrint('AdminRegistrationsScreen: failed to load registrations: $error');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(AppIcons.error, size: 40, color: palette.danger),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Could not load registrations.',
                      style: AppTextStyles.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PremiumButton(
                      label: 'Retry',
                      icon: AppIcons.refresh,
                      variant: PremiumButtonVariant.glass,
                      size: PremiumButtonSize.small,
                      onPressed: () => ref.invalidate(allRegistrationsProvider),
                    ),
                  ],
                ),
              ),
            );
          },
          data: (registrations) {
            Future<void> onRefresh() => ref.refresh(allRegistrationsProvider.future);

            if (registrations.isEmpty) {
              return RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [_EmptyRegistrations()],
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
                      // Sensitive fields (age/gender/emergency contact/
                      // medical notes) live behind this tap rather than in
                      // the list — see AdminRegistrationDetailScreen.
                      onTap: () => context.push(
                        AppConstants.adminRegistrationDetailLocation(registration.id),
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

class _EmptyRegistrations extends StatelessWidget {
  const _EmptyRegistrations();

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
            'Trek registrations will appear here once members sign up for treks.',
            style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RegistrationsSkeleton extends StatelessWidget {
  const _RegistrationsSkeleton();

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

