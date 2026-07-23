import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/gallery/presentation/providers/gallery_providers.dart';
import 'package:doon_walkers/features/gallery/presentation/widgets/gallery_upload_sheet.dart';
import 'package:doon_walkers/features/gallery/presentation/widgets/media_admin_overlay.dart';
import 'package:doon_walkers/features/gallery/presentation/widgets/media_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Gallery grid for a single trek — the Trek Detail screen's "Gallery &
/// Videos" section.
///
/// Same section for every role; an admin additionally gets an inline "Add"
/// button (with this trek pre-selected, since the target is unambiguous
/// here) and per-item delete controls.
///
/// Redesign Phase 3 restyles the loading/empty/error states and the add
/// button onto the design system. The gallery data, the per-item
/// thumbnail/admin-overlay widgets, and the upload flow are all unchanged.
class TrekGallerySection extends ConsumerWidget {
  const TrekGallerySection({
    super.key,
    required this.trekId,
    required this.trekTitle,
  });

  final String trekId;

  /// Used in the delete confirmation copy.
  final String trekTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final mediaAsync = ref.watch(trekGalleryProvider(trekId));

    return mediaAsync.when(
      loading: () => const _GallerySkeleton(),
      error: (error, stack) {
        debugPrint('TrekGallerySection: failed to load media for $trekId: $error');
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Could not load the gallery for this trek.',
                  style: AppTextStyles.tinted(AppTextStyles.bodySmall, AppColors.danger),
                ),
              ),
              PremiumButton(
                label: 'Retry',
                variant: PremiumButtonVariant.ghost,
                size: PremiumButtonSize.small,
                onPressed: () => ref.invalidate(trekGalleryProvider(trekId)),
              ),
            ],
          ),
        );
      },
      data: (media) {
        final addButton = isAdmin
            ? Align(
                alignment: Alignment.centerLeft,
                child: PremiumButton(
                  label: 'Add Photo/Video',
                  icon: AppIcons.addPhoto,
                  variant: PremiumButtonVariant.glass,
                  size: PremiumButtonSize.small,
                  onPressed: () => showGalleryUploadSheet(context, trekId: trekId),
                ),
              )
            : null;

        if (media.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassCard(
                blurEnabled: false,
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Row(
                  children: [
                    const AppIcon(AppIcons.photo, size: 22, color: AppColors.textSecondary),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'No photos or videos for this trek yet.',
                        style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
                      ),
                    ),
                  ],
                ),
              ),
              if (addButton != null) ...[
                const SizedBox(height: AppSpacing.md),
                addButton,
              ],
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: 1,
              ),
              itemCount: media.length,
              itemBuilder: (context, index) {
                final item = media[index];
                return isAdmin
                    ? MediaAdminOverlay(media: item, trekTitle: trekTitle)
                    : MediaThumbnail(
                        media: item,
                        onTap: () => openGalleryMedia(context, item),
                      );
              },
            ),
            if (addButton != null) ...[
              const SizedBox(height: AppSpacing.md),
              addButton,
            ],
          ],
        );
      },
    );
  }
}

/// A short shimmer grid of square placeholders while the gallery loads.
class _GallerySkeleton extends StatelessWidget {
  const _GallerySkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 160,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1,
        ),
        itemCount: 3,
        itemBuilder: (context, index) =>
            const SkeletonBox(height: 160, borderRadius: AppRadius.sm),
      ),
    );
  }
}
