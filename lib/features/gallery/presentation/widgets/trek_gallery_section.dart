import 'package:doon_walkers/features/gallery/presentation/providers/gallery_providers.dart';
import 'package:doon_walkers/features/gallery/presentation/widgets/media_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Gallery grid for a single trek — the Trek Detail screen's "Gallery &
/// Videos" section (Phase 5 filling in the placeholder Phase 4 left for
/// this). Shows every photo/video uploaded for [trekId], or an empty
/// state if none exist yet.
class TrekGallerySection extends ConsumerWidget {
  const TrekGallerySection({super.key, required this.trekId});

  final String trekId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mediaAsync = ref.watch(trekGalleryProvider(trekId));

    return mediaAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Could not load the gallery for this trek.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
        ),
      ),
      data: (media) {
        if (media.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No photos or videos for this trek yet.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          );
        }

        return GridView.builder(
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
            return MediaThumbnail(media: item, onTap: () => openGalleryMedia(context, item));
          },
        );
      },
    );
  }
}
