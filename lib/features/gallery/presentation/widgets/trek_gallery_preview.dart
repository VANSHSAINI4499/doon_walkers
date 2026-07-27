import 'package:cached_network_image/cached_network_image.dart';
import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/gallery/data/services/media_cache_manager.dart';
import 'package:doon_walkers/features/gallery/domain/entities/gallery_media.dart';
import 'package:doon_walkers/features/gallery/presentation/screens/full_screen_media_viewer.dart';
import 'package:doon_walkers/features/gallery/presentation/widgets/gallery_tile.dart';
import 'package:doon_walkers/features/gallery/presentation/widgets/media_admin_overlay.dart';
import 'package:doon_walkers/features/gallery/presentation/widgets/video_thumbnail_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

/// The Trek Detail screen's embedded gallery preview — a 2-column
/// irregular masonry (real per-tile aspect ratios, not uniform
/// squares) of up to the 5 newest items. When the trek has more than 5
/// total, a 6th tile overlays "+N · View All" on the 5th item's image
/// and pushes [TrekGalleryScreen] for the full paginated grid.
///
/// Tapping any real tile opens [openMediaCarousel] against the SAME
/// trek — the fullscreen viewer swipes through the trek's full media
/// list (paginating in more as needed), not just these 5 preview items.
class TrekGalleryPreview extends StatelessWidget {
  const TrekGalleryPreview({
    super.key,
    required this.media,
    required this.totalCount,
    required this.trekId,
    required this.trekTitle,
    required this.isAdmin,
  });

  /// Up to 5 items, newest first — [trekGalleryProvider]'s fetch.
  final List<GalleryMedia> media;

  /// The trek's real total item count — [trekGalleryCountProvider].
  final int totalCount;

  final String trekId;
  final String trekTitle;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final hasOverflow = totalCount > media.length;

    return MasonryGridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      itemCount: media.length + (hasOverflow ? 1 : 0),
      itemBuilder: (context, index) {
        if (hasOverflow && index == media.length) {
          return _ViewAllTile(
            backdrop: media.last,
            remaining: totalCount - media.length,
            onTap:
                () => context.push(
                  '${AppConstants.trekGalleryLocation(trekId)}'
                  '?title=${Uri.encodeComponent(trekTitle)}',
                ),
          );
        }

        final item = media[index];
        void openTapped() => openMediaCarousel(
          context,
          trekId: trekId,
          trekTitle: trekTitle,
          initialIndex: index,
        );

        return isAdmin
            ? MediaAdminOverlay(
              media: item,
              trekTitle: trekTitle,
              onTap: openTapped,
            )
            : GalleryTile(media: item, onTap: openTapped);
      },
    );
  }
}

class _ViewAllTile extends StatelessWidget {
  const _ViewAllTile({
    required this.backdrop,
    required this.remaining,
    required this.onTap,
  });

  final GalleryMedia backdrop;
  final int remaining;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return AspectRatio(
      aspectRatio: backdrop.aspectRatio,
      child: Material(
        color: palette.cardHigh,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Deliberately NOT a GalleryTile here — that widget wraps
              // its content in a Hero keyed to this same media id, and
              // [backdrop] (the 5th item) already renders as its own
              // real GalleryTile elsewhere in this same grid. Two Heroes
              // sharing one tag on the same route is a Flutter
              // assertion failure, so this tile draws the raw image
              // directly instead — it's a dimmed backdrop, not a
              // navigable duplicate of the tile underneath it.
              backdrop.mediaType == MediaType.photo
                  ? CachedNetworkImage(
                    imageUrl: backdrop.mediaUrl,
                    cacheManager: MediaCacheManager.instance.imageCacheManager,
                    fit: BoxFit.cover,
                    placeholder:
                        (context, _) =>
                            Shimmer(child: Container(color: palette.cardHigh)),
                    errorWidget:
                        (context, _, __) => Container(color: palette.cardHigh),
                  )
                  : VideoThumbnailWidget(thumbnailUrl: backdrop.thumbnailUrl),
              Container(color: Colors.black.withAlpha(140)),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '+$remaining',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'View All',
                      style: TextStyle(color: Colors.white, fontSize: 12),
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
