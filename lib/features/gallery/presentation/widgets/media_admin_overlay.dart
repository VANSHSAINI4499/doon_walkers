import 'package:doon_walkers/features/gallery/domain/entities/gallery_media.dart';
import 'package:doon_walkers/features/gallery/presentation/providers/gallery_providers.dart';
import 'package:doon_walkers/features/gallery/presentation/widgets/gallery_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A [GalleryTile] with an inline admin delete affordance layered on
/// top, for use directly on a trek's gallery preview and its full
/// masonry screen.
///
/// Replaces the former standalone admin gallery-management screen: the
/// same grid every member sees gains a small delete button when the
/// viewer is an admin, instead of there being a second parallel screen.
/// `gallery_delete_admin` RLS rejects the delete for anyone else
/// regardless of what renders.
class MediaAdminOverlay extends ConsumerStatefulWidget {
  const MediaAdminOverlay({
    super.key,
    required this.media,
    required this.trekTitle,
    required this.onTap,
  });

  final GalleryMedia media;

  /// Shown in the confirmation dialog so an admin deleting from the
  /// all-treks grid can tell which trek's media they're removing.
  final String trekTitle;

  /// Forwarded straight to the wrapped [GalleryTile] — this widget has
  /// no navigation opinion of its own, the caller decides what tapping
  /// a tile opens (the fullscreen carousel, with the right item list
  /// and start index for wherever this tile lives).
  final VoidCallback onTap;

  @override
  ConsumerState<MediaAdminOverlay> createState() => _MediaAdminOverlayState();
}

class _MediaAdminOverlayState extends ConsumerState<MediaAdminOverlay> {
  bool _isPending = false;

  Future<void> _confirmDelete() async {
    final theme = Theme.of(context);
    final isVideo = widget.media.mediaType == MediaType.video;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete media?'),
        content: Text(
          'This permanently removes this ${isVideo ? 'video' : 'photo'} from '
          '"${widget.trekTitle}", including the file in Storage. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isPending = true);
    final success =
        await ref.read(galleryAdminControllerProvider.notifier).deleteMedia(widget.media.id);
    if (!mounted) return;
    setState(() => _isPending = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not delete media. Please try again.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    // One-shot fetch — refetch the trek's own gallery section.
    ref.invalidate(trekGalleryProvider(widget.media.trekId));
  }

  @override
  Widget build(BuildContext context) {
    // GalleryTile is deliberately the one non-Positioned child here —
    // its own AspectRatio is what gives this cell its intrinsic height
    // inside the masonry grid (a Positioned.fill would need Stack to
    // already know a bounded height, which a masonry delegate doesn't
    // hand down). Stack sizes itself around that child, and the delete
    // button floats on top via Positioned as before.
    return Stack(
      children: [
        GalleryTile(media: widget.media, onTap: widget.onTap),
        Positioned(
          top: 4,
          right: 4,
          child: _isPending
              ? Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(140),
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                )
              : Material(
                  color: Colors.black.withAlpha(140),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _confirmDelete,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.white),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
