import 'dart:typed_data';

import 'package:doon_walkers/features/gallery/domain/entities/gallery_media.dart';
import 'package:doon_walkers/features/gallery/presentation/providers/gallery_providers.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:doon_walkers/features/trek_library/presentation/providers/trek_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Opens the admin media-upload flow as a modal sheet over whichever
/// gallery surface launched it.
///
/// Replaces the former standalone `/admin/gallery/upload` screen: uploads
/// now happen in-place on the public Gallery screen (and on a trek's
/// gallery section), so an admin never leaves the screen they're curating.
///
/// [trekId] pre-selects — and locks — the trek when launched from a
/// specific trek's gallery section, where the target is unambiguous.
/// Passing null shows a trek picker instead.
Future<void> showGalleryUploadSheet(
  BuildContext context, {
  String? trekId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => _GalleryUploadSheet(lockedTrekId: trekId),
  );
}

class _GalleryUploadSheet extends ConsumerStatefulWidget {
  const _GalleryUploadSheet({this.lockedTrekId});

  /// When non-null the trek is fixed and no picker is shown.
  final String? lockedTrekId;

  @override
  ConsumerState<_GalleryUploadSheet> createState() => _GalleryUploadSheetState();
}

class _GalleryUploadSheetState extends ConsumerState<_GalleryUploadSheet> {
  final _captionController = TextEditingController();

  String? _selectedTrekId;
  XFile? _pickedFile;
  Uint8List? _pickedBytes;
  MediaType? _pickedMediaType;

  @override
  void initState() {
    super.initState();
    _selectedTrekId = widget.lockedTrekId;
  }

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

    // One-shot fetches (not live streams) — refetch so the new item shows
    // up on whichever gallery surface launched this sheet.
    ref.invalidate(allGalleryMediaProvider);
    ref.invalidate(trekGalleryProvider(trekId));

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uploaded.')),
    );
  }

  String _trekLabel(Trek trek) => trek.isPublished ? trek.title : '${trek.title} (Draft)';

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

            if (widget.lockedTrekId == null) ...[
              _TrekPicker(
                selectedTrekId: _selectedTrekId,
                labelBuilder: _trekLabel,
                onChanged: (value) => setState(() => _selectedTrekId = value),
              ),
              const SizedBox(height: 20),
            ],

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

/// Trek dropdown for the unscoped (all-treks) upload case. Drafts are
/// included on purpose — an admin may want media staged before publishing.
class _TrekPicker extends ConsumerWidget {
  const _TrekPicker({
    required this.selectedTrekId,
    required this.labelBuilder,
    required this.onChanged,
  });

  final String? selectedTrekId;
  final String Function(Trek) labelBuilder;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treksAsync = ref.watch(adminAllTreksProvider);

    return treksAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, stack) {
        debugPrint('GalleryUploadSheet: failed to load treks: $error');
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
        value: selectedTrekId,
        decoration: const InputDecoration(labelText: 'Trek'),
        items: treks
            .map((t) => DropdownMenuItem(value: t.id, child: Text(labelBuilder(t))))
            .toList(),
        onChanged: onChanged,
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
