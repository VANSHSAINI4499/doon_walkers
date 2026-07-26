import 'package:doon_walkers/core/design_system.dart';
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
          PremiumButton(
            label: 'Cancel',
            variant: PremiumButtonVariant.glass,
            size: PremiumButtonSize.small,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          PremiumButton(
            label: 'Delete',
            icon: AppIcons.delete,
            variant: PremiumButtonVariant.danger,
            size: PremiumButtonSize.small,
            onPressed: () => Navigator.of(dialogContext).pop(true),
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
          backgroundColor: AppPalette.of(context).danger,
        ),
      );
      return;
    }

    // One-shot fetch — refetch the trek's own gallery section.
    ref.invalidate(trekGalleryProvider(widget.media.trekId));
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
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
                    color: palette.scrim,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: palette.textPrimary),
                  ),
                )
              : Material(
                  color: palette.scrim,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _confirmDelete,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: AppIcon(AppIcons.delete, size: 18, color: palette.textPrimary),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
