import 'package:doon_walkers/features/gallery/domain/entities/gallery_media.dart';
import 'package:doon_walkers/features/gallery/presentation/widgets/media_thumbnail.dart';
import 'package:flutter/material.dart';

/// One row in the admin gallery list — thumbnail, trek name, caption,
/// media-type badge, and a delete action. Mirrors AdminTrekListTile's
/// shape (thumbnail + info + pending-aware action). [isPending]
/// disables just this row's delete button while other rows stay usable.
class AdminGalleryListTile extends StatelessWidget {
  const AdminGalleryListTile({
    super.key,
    required this.media,
    required this.trekTitle,
    required this.isPending,
    required this.onDelete,
  });

  final GalleryMedia media;
  final String trekTitle;
  final bool isPending;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caption = media.caption;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: MediaThumbnail(media: media, onTap: () => openGalleryMedia(context, media)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trekTitle,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _MediaTypeChip(mediaType: media.mediaType),
                      if ((caption ?? '').trim().isNotEmpty)
                        Text(
                          caption!,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (isPending)
              const Padding(
                padding: EdgeInsets.all(10),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                tooltip: 'Delete',
              ),
          ],
        ),
      ),
    );
  }
}

class _MediaTypeChip extends StatelessWidget {
  const _MediaTypeChip({required this.mediaType});

  final MediaType mediaType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVideo = mediaType == MediaType.video;
    final color = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isVideo ? Icons.videocam_outlined : Icons.image_outlined, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            isVideo ? 'Video' : 'Photo',
            style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
