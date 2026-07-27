import 'package:cached_network_image/cached_network_image.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/gallery/data/services/media_cache_manager.dart';
import 'package:flutter/material.dart';

/// Renders a video's generated thumbnail frame with a translucent play
/// overlay — never a blank tile. Falls back to a themed placeholder
/// icon (not blank) when [thumbnailUrl] is null, which only happens
/// for videos uploaded before the thumbnail-generation feature landed.
class VideoThumbnailWidget extends StatelessWidget {
  const VideoThumbnailWidget({
    super.key,
    required this.thumbnailUrl,
    this.memCacheWidth,
  });

  final String? thumbnailUrl;

  /// Downsizes the decode to the tile's actual rendered width — keeps
  /// this thumbnail's decoded memory cost separate from (and much
  /// smaller than) the full-resolution frame the fullscreen viewer
  /// would request for the same underlying image.
  final int? memCacheWidth;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final url = thumbnailUrl;

    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        if (url == null || url.isEmpty)
          Container(
            color: palette.cardHigh,
            alignment: Alignment.center,
            child: AppIcon(
              AppIcons.video,
              size: 28,
              color: palette.textSecondary,
            ),
          )
        else
          CachedNetworkImage(
            imageUrl: url,
            cacheManager: MediaCacheManager.instance.imageCacheManager,
            fit: BoxFit.cover,
            memCacheWidth: memCacheWidth,
            placeholder:
                (context, _) =>
                    Shimmer(child: Container(color: palette.cardHigh)),
            errorWidget:
                (context, _, __) => Container(
                  color: palette.cardHigh,
                  alignment: Alignment.center,
                  child: AppIcon(
                    AppIcons.imageBroken,
                    size: 28,
                    color: palette.textSecondary,
                  ),
                ),
          ),
        const _PlayBadge(),
      ],
    );
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withAlpha(140),
      ),
      padding: const EdgeInsets.all(8),
      child: const AppIcon(AppIcons.play, color: Colors.white, size: 20),
    );
  }
}
