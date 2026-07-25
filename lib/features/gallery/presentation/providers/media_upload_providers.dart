import 'package:dio/dio.dart';
import 'package:doon_walkers/features/gallery/data/repositories/gallery_repository_impl.dart';
import 'package:doon_walkers/features/gallery/data/services/media_upload_service.dart';
import 'package:doon_walkers/features/gallery/domain/entities/gallery_media.dart';
import 'package:doon_walkers/features/gallery/domain/entities/media_upload_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

final mediaUploadServiceProvider = Provider<MediaUploadService>(
  (ref) => MediaUploadService(ref.watch(galleryRepositoryProvider)),
  name: 'mediaUploadServiceProvider',
);

/// Live state of every in-flight/recent upload task, across every open
/// upload sheet — deliberately a plain (non-autoDispose) [Notifier] so
/// closing the sheet doesn't cancel or lose track of uploads still
/// running in the background.
final mediaUploadControllerProvider =
    NotifierProvider<MediaUploadController, List<MediaUploadTask>>(
  MediaUploadController.new,
  name: 'mediaUploadControllerProvider',
);

class MediaUploadController extends Notifier<List<MediaUploadTask>> {
  @override
  List<MediaUploadTask> build() => [];

  int _idCounter = 0;
  String _nextId() => 'upload-${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

  /// Tasks belonging to [trekId] — what the upload sheet renders,
  /// newest-batch-first to match the gallery's own ordering.
  List<MediaUploadTask> tasksFor(String trekId) =>
      state.where((t) => t.trekId == trekId).toList().reversed.toList();

  /// Kicks off a batch for every picked file and returns once the whole
  /// batch has settled (each task terminal) — callers that want live
  /// progress should watch [mediaUploadControllerProvider] rather than
  /// await this directly.
  Future<void> startBatch(String trekId, List<XFile> files, {String? caption}) async {
    final service = ref.read(mediaUploadServiceProvider);
    final baseTime = DateTime.now();

    final newTasks = files.map((file) {
      final extension = file.name.contains('.') ? file.name.split('.').last : '';
      final mediaType = MediaType.fromExtension(extension) ?? MediaType.photo;
      return MediaUploadTask(
        id: _nextId(),
        trekId: trekId,
        file: file,
        mediaType: mediaType,
        caption: caption,
        cancelToken: CancelToken(),
      );
    }).toList();

    state = [...state, ...newTasks];

    await service.runBatch(
      trekId: trekId,
      tasks: newTasks,
      baseTime: baseTime,
      onTaskUpdate: _applyUpdate,
    );
  }

  /// Re-runs a failed or cancelled task from scratch with a fresh
  /// [CancelToken].
  Future<void> retry(String taskId) async {
    final index = state.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final retryTask = state[index].copyWith(
      cancelToken: CancelToken(),
      status: MediaUploadStatus.queued,
      progress: 0,
    );
    _applyUpdate(retryTask);

    final service = ref.read(mediaUploadServiceProvider);
    await service.runOne(
      task: retryTask,
      uploadedAt: DateTime.now(),
      onTaskUpdate: _applyUpdate,
    );
  }

  /// Aborts an in-flight upload. A no-op once the task has already
  /// reached a terminal state.
  void cancel(String taskId) {
    final task = state.where((t) => t.id == taskId).firstOrNull;
    if (task == null || task.isTerminal) return;
    task.cancelToken.cancel();
  }

  /// Removes a task from the list — used for terminal (success/failed/
  /// cancelled) rows the admin has acknowledged.
  void dismiss(String taskId) {
    state = state.where((t) => t.id != taskId).toList();
  }

  /// Clears every terminal task for [trekId] — called when the upload
  /// sheet closes so a stale "Uploaded"/"Failed" row from a previous
  /// visit doesn't linger the next time it's opened.
  void clearTerminalFor(String trekId) {
    state = state.where((t) => !(t.trekId == trekId && t.isTerminal)).toList();
  }

  void _applyUpdate(MediaUploadTask updated) {
    final index = state.indexWhere((t) => t.id == updated.id);
    if (index == -1) return;
    final next = [...state];
    next[index] = updated;
    state = next;
  }
}
