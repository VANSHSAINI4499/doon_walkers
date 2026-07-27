import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:doon_walkers/features/gallery/domain/entities/gallery_media.dart';
import 'package:doon_walkers/features/gallery/domain/entities/media_upload_task.dart';
import 'package:doon_walkers/features/gallery/domain/repositories/gallery_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;

/// Orchestrates a multi-file gallery upload batch: compresses photos,
/// generates video thumbnails, decodes real pixel dimensions for the
/// masonry grid, and drives each file through [GalleryRepository.
/// uploadMedia] with bounded concurrency so a large batch doesn't open
/// dozens of sockets at once.
///
/// Stateless — [MediaUploadController] owns the actual task list and
/// calls back into this for each file's work; kept separate so the
/// compression/thumbnail/dimension logic has no Riverpod dependency of
/// its own.
class MediaUploadService {
  const MediaUploadService(this._repository);

  final GalleryRepository _repository;

  static const int maxConcurrentUploads = 3;

  /// Runs every task in [tasks] for [trekId], calling [onTaskUpdate] as
  /// each one's status/progress changes. Does not mutate [tasks] itself
  /// — [MediaUploadController] owns state and applies updates.
  ///
  /// [baseTime] is the batch's start instant; each task's DB
  /// `uploaded_at` is assigned `baseTime + index * 10ms` so the feed's
  /// order always matches the admin's selection order, regardless of
  /// which upload actually finishes first under concurrency.
  Future<void> runBatch({
    required String trekId,
    required List<MediaUploadTask> tasks,
    required DateTime baseTime,
    required void Function(MediaUploadTask updated) onTaskUpdate,
  }) async {
    final orderedTimes = <String, DateTime>{
      for (var i = 0; i < tasks.length; i++)
        tasks[i].id: baseTime.add(Duration(milliseconds: i * 10)),
    };

    final iterator = tasks.iterator;
    Future<void> worker() async {
      while (iterator.moveNext()) {
        final task = iterator.current;
        await _runOne(
          task: task,
          uploadedAt: orderedTimes[task.id]!,
          onTaskUpdate: onTaskUpdate,
        );
      }
    }

    await Future.wait(List.generate(maxConcurrentUploads, (_) => worker()));
  }

  /// Re-runs a single previously failed/cancelled task with a fresh
  /// [CancelToken] — backs [MediaUploadController.retry].
  Future<void> runOne({
    required MediaUploadTask task,
    required DateTime uploadedAt,
    required void Function(MediaUploadTask updated) onTaskUpdate,
  }) => _runOne(task: task, uploadedAt: uploadedAt, onTaskUpdate: onTaskUpdate);

  Future<void> _runOne({
    required MediaUploadTask task,
    required DateTime uploadedAt,
    required void Function(MediaUploadTask updated) onTaskUpdate,
  }) async {
    onTaskUpdate(
      task.copyWith(status: MediaUploadStatus.compressing, progress: 0),
    );

    try {
      final rawBytes = await task.file.readAsBytes();
      final extension = _extensionOf(task.file.name);

      var mediaBytes = rawBytes;
      Uint8List? thumbnailBytes;
      int? width;
      int? height;

      if (task.mediaType == MediaType.photo) {
        mediaBytes = await _compressPhoto(rawBytes);
        final dims = await _decodeDimensions(mediaBytes);
        width = dims?.$1;
        height = dims?.$2;
      } else {
        thumbnailBytes = await _generateVideoThumbnail(task.file.path);
        if (thumbnailBytes != null) {
          final dims = await _decodeDimensions(thumbnailBytes);
          width = dims?.$1;
          height = dims?.$2;
        }
      }

      if (task.cancelToken.isCancelled) {
        onTaskUpdate(task.copyWith(status: MediaUploadStatus.cancelled));
        return;
      }

      onTaskUpdate(
        task.copyWith(status: MediaUploadStatus.uploading, progress: 0),
      );

      final media = await _repository.uploadMedia(
        trekId: task.trekId,
        bytes: mediaBytes,
        fileExtension: extension,
        mediaType: task.mediaType,
        caption: task.caption,
        width: width,
        height: height,
        thumbnailBytes: thumbnailBytes,
        uploadedAt: uploadedAt,
        cancelToken: task.cancelToken,
        onProgress:
            (p) => onTaskUpdate(
              task.copyWith(status: MediaUploadStatus.uploading, progress: p),
            ),
      );

      onTaskUpdate(
        task.copyWith(
          status: MediaUploadStatus.success,
          progress: 1,
          result: media,
        ),
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        onTaskUpdate(task.copyWith(status: MediaUploadStatus.cancelled));
      } else {
        debugPrint(
          'MediaUploadService: upload failed for ${task.file.name}: $e',
        );
        onTaskUpdate(
          task.copyWith(
            status: MediaUploadStatus.failed,
            errorMessage: 'Upload failed.',
          ),
        );
      }
    } catch (e) {
      debugPrint('MediaUploadService: upload failed for ${task.file.name}: $e');
      onTaskUpdate(
        task.copyWith(
          status: MediaUploadStatus.failed,
          errorMessage: 'Something went wrong.',
        ),
      );
    }
  }

  Future<Uint8List> _compressPhoto(Uint8List bytes) async {
    try {
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1920,
        minHeight: 1920,
        quality: 85,
        format: CompressFormat.jpeg,
      );
      // Compression can occasionally return something larger than the
      // source for an already-small/optimized image — keep whichever
      // is smaller rather than penalizing that case.
      return compressed.length < bytes.length ? compressed : bytes;
    } catch (_) {
      // A nice-to-have, not a correctness requirement — fall back to
      // the original bytes rather than failing the whole upload.
      return bytes;
    }
  }

  Future<Uint8List?> _generateVideoThumbnail(String videoPath) async {
    try {
      return await vt.VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: vt.ImageFormat.JPEG,
        maxWidth: 800,
        quality: 75,
      );
    } catch (_) {
      return null;
    }
  }

  Future<(int, int)?> _decodeDimensions(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final dims = (frame.image.width, frame.image.height);
      frame.image.dispose();
      codec.dispose();
      return dims;
    } catch (_) {
      return null;
    }
  }

  String _extensionOf(String filename) {
    final parts = filename.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }
}
