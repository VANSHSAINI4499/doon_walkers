import 'package:cached_network_image/cached_network_image.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/gallery/data/services/media_cache_manager.dart';
import 'package:doon_walkers/features/gallery/domain/entities/gallery_media.dart';
import 'package:doon_walkers/features/gallery/presentation/widgets/video_thumbnail_widget.dart';
import 'package:flutter/material.dart';

/// The masonry grid's atomic cell — a photo or video preview sized to
/// its own real [GalleryMedia.aspectRatio] (not a fixed square),
/// wrapped in a hero flight, Material 3 ripple, a shimmer placeholder,
/// and a fade-in once the image has actually decoded. Replaces the old
/// fixed-square `MediaThumbnail`.
class GalleryTile extends StatelessWidget {
  const GalleryTile({super.key, required this.media, this.onTap, this.heroTag});

  final GalleryMedia media;
  final VoidCallback? onTap;

  /// Defaults to a namespaced tag built from [media.id] — every call
  /// site in this app shows a given media item at most once per route,
  /// so an explicit override is only needed if that ever changes.
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final tag = heroTag ?? AppHeroTags.custom('gallery', media.id);

    return AspectRatio(
      aspectRatio: media.aspectRatio,
      child: AppHero(
        tag: tag,
        fromRadius: AppRadius.sm,
        toRadius: 0,
        child: Material(
          color: AppColors.cardHigh,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child:
                media.mediaType == MediaType.photo
                    ? _PhotoTile(media: media)
                    : VideoThumbnailWidget(thumbnailUrl: media.thumbnailUrl),
          ),
        ),
      ),
    );
  }
}

class _PhotoTile extends StatefulWidget {
  const _PhotoTile({required this.media});

  final GalleryMedia media;

  @override
  State<_PhotoTile> createState() => _PhotoTileState();
}

class _PhotoTileState extends State<_PhotoTile> {
  bool _loaded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Downsizes the decode to what this tile actually renders at —
        // the fullscreen viewer requests the full-resolution image
        // separately, so the two live as distinct ImageCache entries
        // (requirement 7: "cache thumbnails separately").
        final dpr = MediaQuery.of(context).devicePixelRatio;
        final targetWidth =
            constraints.maxWidth.isFinite
                ? (constraints.maxWidth * dpr).round()
                : null;

        return CachedNetworkImage(
          imageUrl: widget.media.mediaUrl,
          cacheManager: MediaCacheManager.instance.imageCacheManager,
          fit: BoxFit.cover,
          memCacheWidth: targetWidth,
          imageBuilder: (context, imageProvider) {
            if (!_loaded) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _loaded = true);
              });
            }
            return AnimatedOpacity(
              opacity: _loaded ? 1 : 0,
              duration: AppMotion.medium,
              child: Image(image: imageProvider, fit: BoxFit.cover),
            );
          },
          placeholder:
              (context, _) =>
                  Shimmer(child: Container(color: AppColors.cardHigh)),
          errorWidget:
              (context, _, __) => Container(
                color: AppColors.cardHigh,
                alignment: Alignment.center,
                child: const AppIcon(
                  AppIcons.imageBroken,
                  color: AppColors.textSecondary,
                ),
              ),
        );
      },
    );
  }
}
