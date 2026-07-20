import 'package:doon_walkers/features/gallery/domain/entities/gallery_media.dart';
import 'package:doon_walkers/features/gallery/presentation/providers/gallery_providers.dart';
import 'package:doon_walkers/features/gallery/presentation/widgets/media_thumbnail.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:doon_walkers/features/trek_library/presentation/providers/trek_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Standalone public Gallery — every photo/video across every
/// *published* trek, grouped into a section per trek (rather than one
/// flat grid) so it reads like a trek showcase, matching the Trek
/// Library's journal feel per AGENTS.md's UI direction.
///
/// Grouping is done client-side against [publishedTreksProvider] — not
/// as an RLS boundary. `gallery_select` has no publish gate (it never
/// did, even before this phase — see Phase 5 audit notes), so media
/// tied to a draft trek is technically still readable via a direct
/// table query. This screen simply never surfaces it in the grouped
/// browse view because it only groups against the published-trek list.
/// See Security Considerations in the Phase 5 report for the full note.
class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treksAsync = ref.watch(publishedTreksProvider);
    final mediaAsync = ref.watch(allGalleryMediaProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gallery')),
      body: SafeArea(
        child: treksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _ErrorState(
            message: 'Could not load the gallery.',
            onRetry: () => ref.invalidate(publishedTreksProvider),
          ),
          data: (treks) => mediaAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => _ErrorState(
              message: 'Could not load the gallery.',
              onRetry: () => ref.invalidate(allGalleryMediaProvider),
            ),
            data: (media) {
              final sections = <(Trek, List<GalleryMedia>)>[];
              for (final trek in treks) {
                final trekMedia = media.where((m) => m.trekId == trek.id).toList();
                if (trekMedia.isNotEmpty) sections.add((trek, trekMedia));
              }

              Future<void> onRefresh() => Future.wait([
                    ref.refresh(publishedTreksProvider.future),
                    ref.refresh(allGalleryMediaProvider.future),
                  ]);

              if (sections.isEmpty) {
                return RefreshIndicator(
                  onRefresh: onRefresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [_EmptyGallery()],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: sections.length,
                  itemBuilder: (context, index) {
                    final (trek, trekMedia) = sections[index];
                    return _TrekGallerySection(trek: trek, media: trekMedia);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TrekGallerySection extends StatelessWidget {
  const _TrekGallerySection({required this.trek, required this.media});

  final Trek trek;
  final List<GalleryMedia> media;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            trek.title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
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
              return MediaThumbnail(media: item, onTap: () => openGalleryMedia(context, item));
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyGallery extends StatelessWidget {
  const _EmptyGallery();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'No photos or videos yet',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Trip photos and videos will show up here once they\'re uploaded.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 40, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(message, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
