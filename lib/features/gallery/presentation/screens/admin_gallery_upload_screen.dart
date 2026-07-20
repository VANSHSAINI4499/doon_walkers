import 'dart:typed_data';

import 'package:doon_walkers/features/gallery/domain/entities/gallery_media.dart';
import 'package:doon_walkers/features/gallery/presentation/providers/gallery_providers.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:doon_walkers/features/trek_library/presentation/providers/trek_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Admin gallery upload — pick a trek, pick a photo or video (media
/// type is auto-detected from the file, never asked of the admin),
/// add an optional caption, upload.
///
/// Reuses [adminAllTreksProvider] from the trek_library feature for the
/// trek picker rather than duplicating a trek list query — drafts are
/// included on purpose, since an admin may want to line up a trek's
/// media before publishing it.
///
/// After a successful upload the form resets (file + caption) but
/// keeps the selected trek, so an admin can upload several photos to
/// the same trek back-to-back without leaving the screen.
class AdminGalleryUploadScreen extends ConsumerStatefulWidget {
  const AdminGalleryUploadScreen({super.key});

  @override
  ConsumerState<AdminGalleryUploadScreen> createState() => _AdminGalleryUploadScreenState();
}

class _AdminGalleryUploadScreenState extends ConsumerState<AdminGalleryUploadScreen> {
  final _captionController = TextEditingController();

  String? _selectedTrekId;
  XFile? _pickedFile;
  Uint8List? _pickedBytes;
  MediaType? _pickedMediaType;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  String _extensionOf(String filename) {
    final parts = filename.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  Future<void> _pickFile() async {
    final xfile = await ImagePicker().pickMedia();
    if (xfile == null) return;

    final extension = _extensionOf(xfile.name);
    final mediaType = MediaType.fromExtension(extension);
    if (mediaType == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unsupported file type. Please choose a JPG, PNG, WEBP, MP4, MOV, or WEBM file.'),
          ),
        );
      }
      return;
    }

    final bytes = await xfile.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedFile = xfile;
      _pickedBytes = bytes;
      _pickedMediaType = mediaType;
    });
  }

  Future<void> _upload() async {
    final trekId = _selectedTrekId;
    final bytes = _pickedBytes;
    final mediaType = _pickedMediaType;
    final file = _pickedFile;
    if (trekId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a trek.')),
      );
      return;
    }
    if (bytes == null || mediaType == null || file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a photo or video.')),
      );
      return;
    }

    final caption = _captionController.text.trim();
    final uploaded = await ref.read(galleryAdminControllerProvider.notifier).uploadMedia(
          trekId: trekId,
          bytes: bytes,
          fileExtension: _extensionOf(file.name),
          mediaType: mediaType,
          caption: caption.isEmpty ? null : caption,
        );

    if (!mounted || uploaded == null) return;

    // allGalleryMediaProvider/trekGalleryProvider are one-shot fetches
    // (not live streams — see their docs), so they need an explicit
    // invalidate to pick up this upload.
    ref.invalidate(allGalleryMediaProvider);
    ref.invalidate(trekGalleryProvider(trekId));

    setState(() {
      _pickedFile = null;
      _pickedBytes = null;
      _pickedMediaType = null;
      _captionController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uploaded.')),
    );
  }

  String _cleanError(Object error) {
    debugPrint('AdminGalleryUploadScreen: upload failed: $error');
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final treksAsync = ref.watch(adminAllTreksProvider);
    final isSaving = ref.watch(galleryAdminControllerProvider).isLoading;

    ref.listen<AsyncValue<void>>(galleryAdminControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stack) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_cleanError(error)),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        },
      );
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Upload Media')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  treksAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, stack) {
                      debugPrint('AdminGalleryUploadScreen: failed to load treks: $error');
                      return InputDecorator(
                        decoration: const InputDecoration(labelText: 'Trek'),
                        child: Row(
                          children: [
                            const Expanded(child: Text('Could not load treks.')),
                            IconButton(
                              icon: const Icon(Icons.refresh_rounded),
                              tooltip: 'Retry',
                              onPressed: () => ref.invalidate(adminAllTreksProvider),
                            ),
                          ],
                        ),
                      );
                    },
                    data: (treks) => DropdownButtonFormField<String>(
                      value: _selectedTrekId,
                      decoration: const InputDecoration(labelText: 'Trek'),
                      items: treks
                          .map((t) => DropdownMenuItem(value: t.id, child: Text(_trekLabel(t))))
                          .toList(),
                      onChanged: (value) => setState(() => _selectedTrekId = value),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _MediaPickerArea(
                    pickedBytes: _pickedBytes,
                    pickedMediaType: _pickedMediaType,
                    fileName: _pickedFile?.name,
                    onTap: _pickFile,
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _captionController,
                    decoration: const InputDecoration(
                      labelText: 'Caption (optional)',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 28),

                  FilledButton(
                    onPressed: isSaving ? null : _upload,
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Upload'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _trekLabel(Trek trek) => trek.isPublished ? trek.title : '${trek.title} (Draft)';
}

class _MediaPickerArea extends StatelessWidget {
  const _MediaPickerArea({
    required this.pickedBytes,
    required this.pickedMediaType,
    required this.fileName,
    required this.onTap,
  });

  final Uint8List? pickedBytes;
  final MediaType? pickedMediaType;
  final String? fileName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surfaceContainerHighest,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: _buildContent(theme),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    final bytes = pickedBytes;
    if (bytes == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_photo_alternate_outlined, size: 36, color: theme.colorScheme.outline),
            const SizedBox(height: 8),
            Text(
              'Tap to choose a photo or video',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    if (pickedMediaType == MediaType.photo) {
      return Image.memory(bytes, fit: BoxFit.cover, width: double.infinity);
    }

    // Video bytes aren't previewed inline here — that would need a
    // second VideoPlayerController just for this form. Confirming the
    // filename is picked is enough for the upload flow to be usable.
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_rounded, size: 36, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              fileName ?? 'Video selected',
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
