import 'package:doon_walkers/features/gallery/domain/entities/gallery_media.dart';
import 'package:doon_walkers/features/gallery/presentation/screens/photo_viewer_screen.dart';
import 'package:doon_walkers/features/gallery/presentation/screens/video_player_screen.dart';
import 'package:flutter/material.dart';

/// Pushes the right full-screen viewer for [media] — [PhotoViewerScreen]
/// for a photo, [VideoPlayerScreen] for a video. Single shared dispatch
/// point so the trek-detail gallery section and the standalone Gallery
/// screen behave identically on tap.
void openGalleryMedia(BuildContext context, GalleryMedia media) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => media.mediaType == MediaType.photo
          ? PhotoViewerScreen(imageUrl: media.mediaUrl, caption: media.caption)
          : VideoPlayerScreen(videoUrl: media.mediaUrl, caption: media.caption),
    ),
  );
}

/// Square grid tile for a [GalleryMedia] item. Photos render the actual
/// image; videos render a placeholder with a play glyph — generating a
/// real video-frame thumbnail would need a separate decode step (e.g.
/// video_thumbnail), which is out of scope for this phase. Tapping
/// either kind is handled by the caller via [onTap] — this widget is
/// purely presentational.
class MediaThumbnail extends StatelessWidget {
  const MediaThumbnail({super.key, required this.media, this.onTap});

  final GalleryMedia media;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          color: theme.colorScheme.surfaceContainerHighest,
          child: media.mediaType == MediaType.photo
              ? Image.network(
                  media.mediaUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Icon(
                    Icons.broken_image_outlined,
                    color: theme.colorScheme.outline,
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.videocam_rounded, size: 28, color: theme.colorScheme.outline),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withAlpha(140),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
