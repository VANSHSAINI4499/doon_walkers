import 'dart:typed_data';

import 'package:doon_walkers/features/gallery/domain/entities/gallery_media.dart';
import 'package:doon_walkers/features/gallery/presentation/providers/gallery_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Opens the admin media-upload flow as a modal sheet over a trek's
/// gallery section — the only place this launches from now that the
/// standalone cross-trek Gallery screen is gone, so [trekId] is always
/// known and required rather than an optional lock.
Future<void> showGalleryUploadSheet(
  BuildContext context, {
  required String trekId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => _GalleryUploadSheet(trekId: trekId),
  );
}

class _GalleryUploadSheet extends ConsumerStatefulWidget {
  const _GalleryUploadSheet({required this.trekId});

  final String trekId;

  @override
  ConsumerState<_GalleryUploadSheet> createState() => _GalleryUploadSheetState();
}

class _GalleryUploadSheetState extends ConsumerState<_GalleryUploadSheet> {
  final _captionController = TextEditingController();

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
            content: Text(
              'Unsupported file type. Please choose a JPG, PNG, WEBP, MP4, MOV, or WEBM file.',
            ),
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

  String _cleanError(Object error) {
    debugPrint('GalleryUploadSheet: upload failed: $error');
    return 'Something went wrong. Please try again.';
  }

  Future<void> _upload() async {
    final bytes = _pickedBytes;
    final mediaType = _pickedMediaType;
    final file = _pickedFile;

    if (bytes == null || mediaType == null || file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a photo or video.')),
      );
      return;
    }

    final caption = _captionController.text.trim();
    final uploaded = await ref.read(galleryAdminControllerProvider.notifier).uploadMedia(
          trekId: widget.trekId,
          bytes: bytes,
          fileExtension: _extensionOf(file.name),
          mediaType: mediaType,
          caption: caption.isEmpty ? null : caption,
        );

    if (!mounted || uploaded == null) return;

    // One-shot fetch (not a live stream) — refetch so the new item shows
    // up on the trek's own gallery section.
    ref.invalidate(trekGalleryProvider(widget.trekId));

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uploaded.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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

    return Padding(
      // Keeps the form above the keyboard when the caption field focuses.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add Photo or Video',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
              decoration: const InputDecoration(labelText: 'Caption (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

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
          ],
        ),
      ),
    );
  }
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

    // Video bytes aren't previewed inline — that would need a second
    // VideoPlayerController just for this form. Confirming the filename
    // is enough for the upload flow to be usable.
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
