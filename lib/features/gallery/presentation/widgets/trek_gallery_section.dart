import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/gallery/presentation/providers/gallery_providers.dart';
import 'package:doon_walkers/features/gallery/presentation/widgets/gallery_upload_sheet.dart';
import 'package:doon_walkers/features/gallery/presentation/widgets/trek_gallery_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

/// Gallery preview for a single trek — the Trek Detail screen's
/// "Gallery & Videos" section.
///
/// Same section for every role; an admin additionally gets an inline
/// "Add" button (with this trek pre-selected, since the target is
/// unambiguous here) and per-item delete controls (via
/// [TrekGalleryPreview]'s [MediaAdminOverlay] tiles).
///
/// The masonry grid rendering itself lives in [TrekGalleryPreview] —
/// this widget owns only the loading/error/empty states, the count
/// fetch, and the admin upload entry point.
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
    final palette = AppPalette.of(context);
    final mediaAsync = ref.watch(trekGalleryProvider(trekId));
    final isAdmin = ref.watch(isAdminProvider);
    final countAsync = ref.watch(trekGalleryCountProvider(trekId));

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
                  style: AppTextStyles.tinted(AppTextStyles.bodySmall, palette.danger),
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
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Row(
                  children: [
                    AppIcon(AppIcons.photo, size: 22, color: palette.textSecondary),
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

        // Falls back to media.length (no overflow tile) while the count
        // query is still in flight or failed — same info the preview
        // already has, just without the "+N" tile until the real total
        // is known.
        final totalCount = countAsync.valueOrNull ?? media.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrekGalleryPreview(
              media: media,
              totalCount: totalCount,
              trekId: trekId,
              trekTitle: trekTitle,
              isAdmin: isAdmin,
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

/// A short shimmer grid of placeholders while the gallery loads.
class _GallerySkeleton extends StatelessWidget {
  const _GallerySkeleton();

  static const _heights = [150.0, 110.0, 130.0];

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: MasonryGridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        itemCount: _heights.length,
        itemBuilder: (context, index) =>
            SkeletonBox(height: _heights[index], borderRadius: AppRadius.sm),
      ),
    );
  }
}
