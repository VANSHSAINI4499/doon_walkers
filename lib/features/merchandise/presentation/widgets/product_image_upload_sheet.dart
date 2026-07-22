import 'dart:typed_data';

import 'package:doon_walkers/features/merchandise/presentation/providers/product_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Opens the admin photo-upload flow as a modal sheet over a product's
/// image section. Mirrors [showGalleryUploadSheet] — a single photo at
/// a time, no caption field (products don't have per-photo captions,
/// unlike trek gallery media) and no video branch (the `merch-images`
/// bucket only accepts image mime types).
Future<void> showProductImageUploadSheet(
  BuildContext context, {
  required String productId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => _ProductImageUploadSheet(productId: productId),
  );
}

class _ProductImageUploadSheet extends ConsumerStatefulWidget {
  const _ProductImageUploadSheet({required this.productId});

  final String productId;

  @override
  ConsumerState<_ProductImageUploadSheet> createState() => _ProductImageUploadSheetState();
}

class _ProductImageUploadSheetState extends ConsumerState<_ProductImageUploadSheet> {
  static const _allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  Uint8List? _pickedBytes;
  String? _pickedExtension;

  String _extensionOf(String filename) {
    final parts = filename.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  Future<void> _pickImage() async {
    final xfile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (xfile == null) return;

    final extension = _extensionOf(xfile.name);
    if (!_allowedExtensions.contains(extension)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please choose a JPG, PNG, or WEBP image.')),
        );
      }
      return;
    }

    final bytes = await xfile.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedBytes = bytes;
      _pickedExtension = extension;
    });
  }

  String _cleanError(Object error) {
    debugPrint('ProductImageUploadSheet: upload failed: $error');
    return 'Something went wrong. Please try again.';
  }

  Future<void> _upload() async {
    final bytes = _pickedBytes;
    final extension = _pickedExtension;

    if (bytes == null || extension == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a photo.')),
      );
      return;
    }

    final uploaded = await ref.read(productImageAdminControllerProvider.notifier).uploadImage(
          productId: widget.productId,
          bytes: bytes,
          fileExtension: extension,
        );

    if (!mounted || uploaded == null) return;

    // One-shot fetch (not a live stream) — refetch so the new photo
    // shows up on the product's own detail page.
    ref.invalidate(productByIdProvider(widget.productId));

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uploaded.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSaving = ref.watch(productImageAdminControllerProvider).isLoading;

    ref.listen<AsyncValue<void>>(productImageAdminControllerProvider, (previous, next) {
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
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add Photo',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 180,
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: theme.colorScheme.surfaceContainerHighest,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: _pickedBytes == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 36,
                              color: theme.colorScheme.outline,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to choose a photo',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                    : Image.memory(_pickedBytes!, fit: BoxFit.cover, width: double.infinity),
              ),
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
