import 'dart:async';
import 'dart:io';

import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/gallery/domain/entities/gallery_media.dart';
import 'package:doon_walkers/features/gallery/domain/entities/media_upload_task.dart';
import 'package:doon_walkers/features/gallery/presentation/providers/gallery_providers.dart';
import 'package:doon_walkers/features/gallery/presentation/providers/media_upload_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Opens the admin media-upload flow as a modal sheet over a trek's
/// gallery section.
///
/// Multi-file: picks any mix of photos and videos in one go
/// ([ImagePicker.pickMultipleMedia]) and shows one row per file with
/// its own live progress, cancel (while uploading), and retry (on
/// failure) — driven by [mediaUploadControllerProvider], which keeps
/// running uploads even if this sheet is dismissed early.
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
  ConsumerState<_GalleryUploadSheet> createState() =>
      _GalleryUploadSheetState();
}

class _GalleryUploadSheetState extends ConsumerState<_GalleryUploadSheet> {
  final _captionController = TextEditingController();
  List<XFile> _picked = [];
  bool _isPicking = false;
  bool _isStarting = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    setState(() => _isPicking = true);
    try {
      final files = await ImagePicker().pickMultipleMedia();
      if (!mounted) return;
      // Silently drop anything not photo/video-shaped — pickMultipleMedia
      // itself already filters to the OS media picker, this only guards
      // against an extension this bucket doesn't accept.
      final valid = files.where(
        (f) => MediaType.fromExtension(_extensionOf(f.name)) != null,
      );
      setState(() => _picked = [..._picked, ...valid]);
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _removePicked(XFile file) {
    setState(
      () => _picked = _picked.where((f) => f.path != file.path).toList(),
    );
  }

  String _extensionOf(String filename) {
    final parts = filename.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  Future<void> _startUpload() async {
    if (_picked.isEmpty) return;
    final caption = _captionController.text.trim();
    final files = _picked;

    setState(() {
      _isStarting = true;
      _picked = [];
      _captionController.clear();
    });

    // Deliberately not awaited by the UI beyond kicking it off — the
    // controller keeps the batch running (and this sheet's task list
    // updating) even after the sheet closes.
    unawaited(
      ref
          .read(mediaUploadControllerProvider.notifier)
          .startBatch(
            widget.trekId,
            files,
            caption: caption.isEmpty ? null : caption,
          ),
    );

    if (mounted) setState(() => _isStarting = false);
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(
      mediaUploadControllerProvider.select(
        (state) =>
            state
                .where((t) => t.trekId == widget.trekId)
                .toList()
                .reversed
                .toList(),
      ),
    );

    // A settled batch (every task terminal) means the trek's own
    // gallery preview/count are stale — refetch once, right when the
    // last task in flight lands.
    ref.listen(mediaUploadControllerProvider, (previous, next) {
      final wasActive = (previous ?? []).any(
        (t) => t.trekId == widget.trekId && t.isActive,
      );
      final stillActive = next.any(
        (t) => t.trekId == widget.trekId && t.isActive,
      );
      if (wasActive && !stillActive) {
        ref.invalidate(trekGalleryProvider(widget.trekId));
        ref.invalidate(trekGalleryCountProvider(widget.trekId));
      }
    });

    return Padding(
      // Keeps the form above the keyboard when the caption field focuses.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xs,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add Photos & Videos', style: AppTextStyles.titleLarge),
              const SizedBox(height: AppSpacing.lg),

              if (tasks.isNotEmpty) ...[
                Text(
                  'Uploading',
                  style: AppTextStyles.secondary(AppTextStyles.labelMedium),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...tasks.map((task) => _UploadTaskRow(task: task)),
                const SizedBox(height: AppSpacing.lg),
              ],

              _PickedFilesGrid(
                files: _picked,
                onRemove: _removePicked,
                onAddMore: _pickFiles,
              ),
              const SizedBox(height: AppSpacing.lg),

              TextFormField(
                controller: _captionController,
                decoration: const InputDecoration(
                  labelText: 'Caption for this batch (optional)',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.xl),

              PremiumButton(
                label:
                    _picked.isEmpty
                        ? 'Choose Photos or Videos'
                        : 'Upload ${_picked.length} item${_picked.length == 1 ? '' : 's'}',
                icon: AppIcons.upload,
                fullWidth: true,
                isLoading: _isStarting,
                onPressed:
                    (_picked.isEmpty || _isPicking || _isStarting)
                        ? null
                        : _startUpload,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickedFilesGrid extends StatelessWidget {
  const _PickedFilesGrid({
    required this.files,
    required this.onRemove,
    required this.onAddMore,
  });

  final List<XFile> files;
  final void Function(XFile) onRemove;
  final VoidCallback onAddMore;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final file in files)
          _PickedFileChip(file: file, onRemove: () => onRemove(file)),
        GestureDetector(
          onTap: onAddMore,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              color: palette.cardHigh,
              border: Border.all(color: palette.border),
            ),
            child: AppIcon(
              files.isEmpty ? AppIcons.addPhoto : AppIcons.add,
              color: palette.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _PickedFileChip extends StatelessWidget {
  const _PickedFileChip({required this.file, required this.onRemove});

  final XFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final extension =
        file.name.contains('.') ? file.name.split('.').last.toLowerCase() : '';
    final isVideo = MediaType.fromExtension(extension) == MediaType.video;

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            width: 72,
            height: 72,
            color: palette.cardHigh,
            alignment: Alignment.center,
            child:
                isVideo
                    ? AppIcon(AppIcons.video, color: palette.textSecondary)
                    : Image.file(
                      File(file.path),
                      fit: BoxFit.cover,
                      width: 72,
                      height: 72,
                    ),
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: Material(
            color: palette.scrim,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onRemove,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: AppIcon(
                  AppIcons.close,
                  size: 14,
                  color: palette.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UploadTaskRow extends ConsumerWidget {
  const _UploadTaskRow({required this.task});

  final MediaUploadTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: SizedBox(
              width: 40,
              height: 40,
              child:
                  task.mediaType == MediaType.photo
                      ? Image.file(
                        File(task.file.path),
                        fit: BoxFit.cover,
                        errorBuilder:
                            (context, _, __) =>
                                Container(color: palette.cardHigh),
                      )
                      : Container(
                        color: palette.cardHigh,
                        alignment: Alignment.center,
                        child: const AppIcon(AppIcons.video, size: 18),
                      ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 4),
                _StatusLine(task: task),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _TrailingAction(task: task),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.task});

  final MediaUploadTask task;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    switch (task.status) {
      case MediaUploadStatus.queued:
        return Text(
          'Queued…',
          style: AppTextStyles.secondary(AppTextStyles.labelSmall),
        );
      case MediaUploadStatus.compressing:
        return Text(
          'Preparing…',
          style: AppTextStyles.secondary(AppTextStyles.labelSmall),
        );
      case MediaUploadStatus.uploading:
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: task.progress.clamp(0, 1).toDouble(),
            minHeight: 4,
            backgroundColor: palette.cardHigh,
          ),
        );
      case MediaUploadStatus.success:
        return Text(
          'Uploaded',
          style: AppTextStyles.tinted(
            AppTextStyles.labelSmall,
            palette.primary,
          ),
        );
      case MediaUploadStatus.failed:
        return Text(
          task.errorMessage ?? 'Failed',
          style: AppTextStyles.tinted(AppTextStyles.labelSmall, palette.danger),
        );
      case MediaUploadStatus.cancelled:
        return Text(
          'Cancelled',
          style: AppTextStyles.secondary(AppTextStyles.labelSmall),
        );
    }
  }
}

class _TrailingAction extends ConsumerWidget {
  const _TrailingAction({required this.task});

  final MediaUploadTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    if (task.isActive) {
      return IconButton(
        icon: const AppIcon(AppIcons.close, size: 18),
        tooltip: 'Cancel',
        onPressed:
            () => ref
                .read(mediaUploadControllerProvider.notifier)
                .cancel(task.id),
      );
    }
    if (task.status == MediaUploadStatus.failed) {
      return IconButton(
        icon: const AppIcon(AppIcons.refresh, size: 18),
        tooltip: 'Retry',
        onPressed:
            () =>
                ref.read(mediaUploadControllerProvider.notifier).retry(task.id),
      );
    }
    if (task.status == MediaUploadStatus.success) {
      return AppIcon(AppIcons.checkCircle, size: 18, color: palette.primary);
    }
    // Queued or cancelled — dismissible.
    return IconButton(
      icon: const AppIcon(AppIcons.close, size: 18),
      tooltip: 'Remove',
      onPressed:
          () =>
              ref.read(mediaUploadControllerProvider.notifier).dismiss(task.id),
    );
  }
}
