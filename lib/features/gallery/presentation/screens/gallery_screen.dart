import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/gallery/domain/entities/gallery_media.dart';
import 'package:doon_walkers/features/gallery/presentation/providers/gallery_providers.dart';
import 'package:doon_walkers/features/gallery/presentation/widgets/gallery_upload_sheet.dart';
import 'package:doon_walkers/features/gallery/presentation/widgets/media_admin_overlay.dart';
import 'package:doon_walkers/features/gallery/presentation/widgets/media_thumbnail.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:doon_walkers/features/trek_library/presentation/providers/trek_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Gallery — one shared screen for every role, grouped into a section per
/// trek so it reads like a trek showcase (per AGENTS.md's UI direction).
///
/// An admin sees the same screen plus inline management: an "Add Photo or
/// Video" button and a per-item delete control. There is deliberately no
/// separate admin gallery-management screen.
///
/// Grouping is done client-side against the trek list — not as an RLS
/// boundary. Which treks that list contains is role-dependent
/// ([adminAllTreksProvider] vs [publishedTreksProvider]) so an admin can
/// curate media on a draft trek before it goes live, while members only
/// ever see sections for published treks. `gallery_select` independently
/// gates draft-trek media server-side (0008_gallery_select_publish_gate).
class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final treksProvider = isAdmin ? adminAllTreksProvider : publishedTreksProvider;
    final treksAsync = ref.watch(treksProvider);
    final mediaAsync = ref.watch(allGalleryMediaProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gallery')),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => showGalleryUploadSheet(context),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Add Media'),
            )
          : null,
      body: SafeArea(
        child: treksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) {
            debugPrint('GalleryScreen: failed to load treks: $error');
            return _ErrorState(
              message: 'Could not load the gallery.',
              onRetry: () => ref.invalidate(treksProvider),
            );
          },
          data: (treks) => mediaAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) {
              debugPrint('GalleryScreen: failed to load media: $error');
              return _ErrorState(
                message: 'Could not load the gallery.',
                onRetry: () => ref.invalidate(allGalleryMediaProvider),
              );
            },
            data: (media) {
              final sections = <(Trek, List<GalleryMedia>)>[];
              for (final trek in treks) {
                final trekMedia = media.where((m) => m.trekId == trek.id).toList();
                if (trekMedia.isNotEmpty) sections.add((trek, trekMedia));
              }

              Future<void> onRefresh() => Future.wait([
                    ref.refresh(treksProvider.future),
                    ref.refresh(allGalleryMediaProvider.future),
                  ]);

              if (sections.isEmpty) {
                return RefreshIndicator(
                  onRefresh: onRefresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [_EmptyGallery(isAdmin: isAdmin)],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, 16, 16, isAdmin ? 96 : 16),
                  itemCount: sections.length,
                  itemBuilder: (context, index) {
                    final (trek, trekMedia) = sections[index];
                    return _TrekGallerySection(
                      trek: trek,
                      media: trekMedia,
                      isAdmin: isAdmin,
                    );
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
  const _TrekGallerySection({
    required this.trek,
    required this.media,
    required this.isAdmin,
  });

  final Trek trek;
  final List<GalleryMedia> media;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  trek.title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Only an admin ever sees a draft trek's section here.
              if (isAdmin && !trek.isPublished)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Draft',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
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
              return isAdmin
                  ? MediaAdminOverlay(media: item, trekTitle: trek.title)
                  : MediaThumbnail(
                      media: item,
                      onTap: () => openGalleryMedia(context, item),
                    );
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyGallery extends StatelessWidget {
  const _EmptyGallery({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
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
            isAdmin
                ? 'Tap "Add Media" to upload the first photo or video.'
                : "Trip photos and videos will show up here once they're uploaded.",
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
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
