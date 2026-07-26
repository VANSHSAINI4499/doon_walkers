import 'dart:typed_data';

import 'package:doon_walkers/core/design_system.dart';
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
    return AppCard(
      height: 180,
      padding: EdgeInsets.zero,
      onTap: _pick,
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final initialImageUrl = widget.initialImageUrl;

    if (_pickedBytes != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(_pickedBytes!, fit: BoxFit.cover),
          _editBadge(context),
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
            errorBuilder: (context, error, stack) => _placeholder(context),
          ),
          _editBadge(context),
        ],
      );
    }

    return _placeholder(context, showHint: true);
  }

  Widget _editBadge(BuildContext context) {
    final palette = AppPalette.of(context);
    return Positioned(
      right: AppSpacing.sm,
      bottom: AppSpacing.sm,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: palette.scrim,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        child: AppIcon(AppIcons.edit, size: 16, color: palette.textPrimary),
      ),
    );
  }

  Widget _placeholder(BuildContext context, {bool showHint = false}) {
    final palette = AppPalette.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(AppIcons.addPhoto, size: 32, color: palette.textDisabled),
          if (showHint) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(widget.hintText, style: AppTextStyles.secondary(AppTextStyles.bodySmall)),
          ],
        ],
      ),
    );
  }
}
