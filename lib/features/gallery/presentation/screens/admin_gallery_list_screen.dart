import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/features/gallery/domain/entities/gallery_media.dart';
import 'package:doon_walkers/features/gallery/presentation/providers/gallery_providers.dart';
import 'package:doon_walkers/features/gallery/presentation/widgets/admin_gallery_list_tile.dart';
import 'package:doon_walkers/features/trek_library/presentation/providers/trek_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Admin gallery management — every media row across every trek in one
/// list (rather than one screen per trek), with a trek filter dropdown
/// to narrow it down. Reachable only via the admin-gated
/// `/admin/gallery` route; RLS backs this up independently on both the
/// `gallery` table and the `trek-gallery` storage bucket.
class AdminGalleryListScreen extends ConsumerStatefulWidget {
  const AdminGalleryListScreen({super.key});

  @override
  ConsumerState<AdminGalleryListScreen> createState() => _AdminGalleryListScreenState();
}

class _AdminGalleryListScreenState extends ConsumerState<AdminGalleryListScreen> {
  String? _trekFilter; // null = all treks
  String? _pendingId;

  Future<void> _confirmDelete(GalleryMedia media, String trekTitle) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete media?'),
        content: Text(
          'This permanently removes this ${media.mediaType == MediaType.video ? 'video' : 'photo'} '
          'from "$trekTitle", including the file in Storage. This cannot be undone.',
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

    setState(() => _pendingId = media.id);
    final success = await ref.read(galleryAdminControllerProvider.notifier).deleteMedia(media.id);
    if (!mounted) return;
    setState(() => _pendingId = null);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not delete media. Please try again.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaAsync = ref.watch(allGalleryMediaProvider);
    final treksAsync = ref.watch(adminAllTreksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Gallery')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppConstants.routeAdminGalleryUpload),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Upload Media'),
      ),
      body: treksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load treks: $error', textAlign: TextAlign.center),
          ),
        ),
        data: (treks) {
          final trekTitles = {for (final t in treks) t.id: t.title};

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: DropdownButtonFormField<String?>(
                  value: _trekFilter,
                  decoration: const InputDecoration(labelText: 'Filter by trek'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All treks')),
                    ...treks.map((t) => DropdownMenuItem(value: t.id, child: Text(t.title))),
                  ],
                  onChanged: (value) => setState(() => _trekFilter = value),
                ),
              ),
              Expanded(
                child: mediaAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Could not load gallery media: $error', textAlign: TextAlign.center),
                    ),
                  ),
                  data: (allMedia) {
                    final media = _trekFilter == null
                        ? allMedia
                        : allMedia.where((m) => m.trekId == _trekFilter).toList();

                    if (media.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.photo_library_outlined, size: 48, color: theme.colorScheme.outline),
                              const SizedBox(height: 16),
                              Text(
                                _trekFilter == null ? 'No media uploaded yet' : 'No media for this trek yet',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap "Upload Media" to add the first photo or video.',
                                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      itemCount: media.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = media[index];
                        final trekTitle = trekTitles[item.trekId] ?? 'Unknown trek';
                        return AdminGalleryListTile(
                          media: item,
                          trekTitle: trekTitle,
                          isPending: _pendingId == item.id,
                          onDelete: () => _confirmDelete(item, trekTitle),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
