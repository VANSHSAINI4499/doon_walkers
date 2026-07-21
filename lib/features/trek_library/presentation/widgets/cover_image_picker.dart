import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Tap-to-pick image field for the admin trek form. Shows a
/// newly-picked image if there is one, else the trek's existing
/// [initialImageUrl] (edit mode), else an empty placeholder.
///
/// Only reports the pick back to the parent via [onImagePicked] — it
/// doesn't upload anything itself. Upload happens when the form is
/// submitted (see TrekAdminController), so backing out of the form
/// without saving never touches Storage.
///
/// Generic enough to double as the payment QR code picker
/// ([hintText] is the only thing that differs) — both are a single
/// admin-picked image feeding a `TrekAdminController` upload method,
/// just targeting a different trek column.
class CoverImagePicker extends StatefulWidget {
  const CoverImagePicker({
    super.key,
    required this.onImagePicked,
    this.initialImageUrl,
    this.hintText = 'Tap to add a cover image',
  });

  final String? initialImageUrl;
  final void Function(Uint8List bytes, String fileExtension) onImagePicked;
  final String hintText;

  @override
  State<CoverImagePicker> createState() => _CoverImagePickerState();
}

class _CoverImagePickerState extends State<CoverImagePicker> {
  static const _allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  Uint8List? _pickedBytes;

  Future<void> _pick() async {
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
    setState(() => _pickedBytes = bytes);
    widget.onImagePicked(bytes, extension);
  }

  String _extensionOf(String filename) {
    final parts = filename.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : 'jpg';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: _pick,
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
    final initialImageUrl = widget.initialImageUrl;

    if (_pickedBytes != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(_pickedBytes!, fit: BoxFit.cover),
          _editBadge(),
        ],
      );
    }

    if (initialImageUrl != null && initialImageUrl.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            initialImageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => _placeholder(theme),
          ),
          _editBadge(),
        ],
      );
    }

    return _placeholder(theme, showHint: true);
  }

  Widget _editBadge() {
    return Positioned(
      right: 8,
      bottom: 8,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(140),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.edit_rounded, size: 16, color: Colors.white),
      ),
    );
  }

  Widget _placeholder(ThemeData theme, {bool showHint = false}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_photo_alternate_outlined, size: 36, color: theme.colorScheme.outline),
          if (showHint) ...[
            const SizedBox(height: 8),
            Text(
              widget.hintText,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
