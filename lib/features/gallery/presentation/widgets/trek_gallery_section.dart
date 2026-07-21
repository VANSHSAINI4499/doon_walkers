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
/// Same section for every role; an admin additionally gets an inline
/// "Add" button (with this trek pre-selected, since the target is
/// unambiguous here) and per-item delete controls.
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
    final theme = Theme.of(context);
    final isAdmin = ref.watch(isAdminProvider);
    final mediaAsync = ref.watch(trekGalleryProvider(trekId));

    return mediaAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) {
        debugPrint('TrekGallerySection: failed to load media for $trekId: $error');
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Could not load the gallery for this trek.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ),
              TextButton(
                onPressed: () => ref.invalidate(trekGalleryProvider(trekId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      },
      data: (media) {
        final addButton = isAdmin
            ? Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => showGalleryUploadSheet(context, trekId: trekId),
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                  label: const Text('Add Photo/Video'),
                ),
              )
            : null;

        if (media.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No photos or videos for this trek yet.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (addButton != null) addButton,
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
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
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
              const SizedBox(height: 12),
              addButton,
            ],
          ],
        );
      },
    );
  }
}
