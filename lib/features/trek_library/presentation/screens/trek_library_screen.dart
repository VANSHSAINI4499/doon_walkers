import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/trek_library/presentation/providers/trek_providers.dart';
import 'package:doon_walkers/features/trek_library/presentation/widgets/trek_admin_actions.dart';
import 'package:doon_walkers/features/trek_library/presentation/widgets/trek_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

/// Trek Library — one shared screen for every role.
///
/// Guests and members see published treks only. An admin sees the same
/// screen plus inline management: drafts included (marked as such), a
/// per-trek actions menu, and an "Add Trek" button. There is deliberately
/// no separate admin trek-management screen — the admin controls live
/// here so there's a single source of truth for how a trek is presented.
///
/// The role split is purely which provider feeds the grid:
/// [adminAllTreksProvider] (published + draft) vs [publishedTreksProvider].
/// RLS enforces the same split server-side — `treks_select` only returns
/// unpublished rows to an admin caller — so a non-admin can't obtain
/// drafts even if this widget asked for them.
///
/// Redesign Phase 3: rebuilt on the design system (skeleton loading,
/// glass trek cards, a gradient add-trek button). The role split, the
/// masonry layout, and every gating rule are unchanged.
class TrekLibraryScreen extends ConsumerWidget {
  const TrekLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final treksProvider = isAdmin ? adminAllTreksProvider : publishedTreksProvider;
    final treksAsync = ref.watch(treksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Trek Library')),
      floatingActionButton: isAdmin
          ? _AddTrekFab(onTap: () => context.push(AppConstants.routeTrekNew))
          : null,
      body: SafeArea(
        child: treksAsync.when(
          loading: () => const _TrekGridSkeleton(),
          error: (error, stack) {
            debugPrint('TrekLibraryScreen: failed to load treks: $error');
            return _TrekLibraryError(onRetry: () => ref.invalidate(treksProvider));
          },
          data: (treks) {
            Future<void> onRefresh() => ref.refresh(treksProvider.future);

            if (treks.isEmpty) {
              return RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [_EmptyTrekLibrary(isAdmin: isAdmin)],
                ),
              );
            }

            // A masonry grid, not a fixed-childAspectRatio GridView — a
            // trek's description length varies row to row, so a fixed cell
            // height either wastes space below short content or clips long
            // content. MasonryGridView sizes each card to its own
            // intrinsic height and packs them into columns, so short- and
            // long-description cards both look correct.
            return RefreshIndicator(
              onRefresh: onRefresh,
              child: MasonryGridView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                // Extra bottom padding for admins so the FAB never covers
                // the last row's action menu.
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  isAdmin ? 96 : AppSpacing.lg,
                ),
                gridDelegate: const SliverSimpleGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 340,
                ),
                mainAxisSpacing: AppSpacing.lg,
                crossAxisSpacing: AppSpacing.lg,
                itemCount: treks.length,
                itemBuilder: (context, index) {
                  final trek = treks[index];
                  return AppReveal(
                    index: index.clamp(0, 8),
                    child: TrekCard(
                      trek: trek,
                      onTap: () => context.push(AppConstants.trekDetailLocation(trek.id)),
                      adminActions: isAdmin ? TrekAdminActions(trek: trek) : null,
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

/// Gradient "Add Trek" button — the design system's take on an extended
/// FAB. Admin-only; the caller gates it (RLS gates the writes it leads to).
class _AddTrekFab extends StatelessWidget {
  const _AddTrekFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          gradient: AppGradients.primary,
          borderRadius: BorderRadius.circular(AppRadius.button),
          boxShadow: AppShadows.button(AppColors.primary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon(AppIcons.add, size: 22, color: AppColors.onPrimary),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Add Trek',
              style: AppTextStyles.tinted(AppTextStyles.labelLarge, AppColors.onPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrekLibraryError extends StatelessWidget {
  const _TrekLibraryError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon(AppIcons.error, size: 44, color: AppColors.danger),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Could not load treks.',
              style: AppTextStyles.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            PremiumButton(
              label: 'Retry',
              icon: AppIcons.refresh,
              variant: PremiumButtonVariant.glass,
              size: PremiumButtonSize.small,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTrekLibrary extends StatelessWidget {
  const _EmptyTrekLibrary({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: const AppIcon(AppIcons.hiking, size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            isAdmin ? 'No treks yet' : 'No treks published yet',
            style: AppTextStyles.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            isAdmin
                ? 'Tap "Add Trek" to create the first one.'
                : 'Check back soon — new treks are on the way.',
            style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Trek-card-shaped placeholders while the grid loads, matching the real
/// masonry layout and the Phase 1 skeleton style.
class _TrekGridSkeleton extends StatelessWidget {
  const _TrekGridSkeleton();

  // Varied heights so the skeleton reads as a masonry grid, not a table.
  static const _imageHeights = [140.0, 120.0, 120.0, 150.0, 130.0, 120.0];

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: MasonryGridView.count(
        crossAxisCount: 2,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        mainAxisSpacing: AppSpacing.lg,
        crossAxisSpacing: AppSpacing.lg,
        itemCount: _imageHeights.length,
        itemBuilder: (context, index) => _TrekCardSkeleton(
          imageHeight: _imageHeights[index],
          showDescription: index.isEven,
        ),
      ),
    );
  }
}

class _TrekCardSkeleton extends StatelessWidget {
  const _TrekCardSkeleton({required this.imageHeight, required this.showDescription});

  final double imageHeight;
  final bool showDescription;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SkeletonBox(height: imageHeight, borderRadius: 0),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SkeletonBox(width: 130, height: 16),
                if (showDescription) ...[
                  const SizedBox(height: AppSpacing.md),
                  const SkeletonText(lines: 2, lineHeight: 10),
                ],
                const SizedBox(height: AppSpacing.md),
                const Row(
                  children: [
                    SkeletonBox(width: 56, height: 24, borderRadius: AppRadius.sm),
                    SizedBox(width: AppSpacing.sm),
                    SkeletonBox(width: 56, height: 24, borderRadius: AppRadius.sm),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
