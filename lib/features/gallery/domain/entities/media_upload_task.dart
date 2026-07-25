import 'package:dio/dio.dart';
import 'package:doon_walkers/features/gallery/domain/entities/gallery_media.dart';
import 'package:image_picker/image_picker.dart';

/// Lifecycle of one file within a [MediaUploadService] batch.
enum MediaUploadStatus {
  queued,
  compressing,
  uploading,
  success,
  failed,
  cancelled,
}

/// Per-file state for a multi-file upload batch — what the upload
/// sheet's per-row progress bar / status chip / cancel-or-retry button
/// renders. Immutable; [MediaUploadController] replaces entries via
/// [copyWith] as a task progresses.
class MediaUploadTask {
  const MediaUploadTask({
    required this.id,
    required this.trekId,
    required this.file,
    required this.mediaType,
    required this.cancelToken,
    this.caption,
    this.status = MediaUploadStatus.queued,
    this.progress = 0,
    this.errorMessage,
    this.result,
  });

  final String id;
  final String trekId;
  final XFile file;
  final MediaType mediaType;

  /// The batch's single shared caption (if any) — applied to every
  /// file in the batch. Per-file captions aren't offered in the
  /// upload sheet's UI.
  final String? caption;

  /// Fresh per attempt — [MediaUploadController.retry] replaces this
  /// with a new, uncancelled token so a previously-cancelled upload can
  /// genuinely be retried rather than immediately cancelling again.
  final CancelToken cancelToken;

  final MediaUploadStatus status;

  /// 0.0–1.0. For videos this already accounts for the thumbnail
  /// upload's share of the task — see [GalleryRepositoryImpl.uploadMedia].
  final double progress;

  final String? errorMessage;
  final GalleryMedia? result;

  bool get isTerminal =>
      status == MediaUploadStatus.success ||
      status == MediaUploadStatus.failed ||
      status == MediaUploadStatus.cancelled;

  bool get isActive =>
      status == MediaUploadStatus.compressing || status == MediaUploadStatus.uploading;

  MediaUploadTask copyWith({
    CancelToken? cancelToken,
    MediaUploadStatus? status,
    double? progress,
    String? errorMessage,
    GalleryMedia? result,
  }) {
    return MediaUploadTask(
      id: id,
      trekId: trekId,
      file: file,
      mediaType: mediaType,
      caption: caption,
      cancelToken: cancelToken ?? this.cancelToken,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage,
      result: result ?? this.result,
    );
  }
}
