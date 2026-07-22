import 'dart:async';
import 'dart:typed_data';

import 'package:doon_walkers/features/gallery/data/repositories/gallery_repository_impl.dart';
import 'package:doon_walkers/features/gallery/domain/entities/gallery_media.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Media for a single trek — Trek Detail screen's embedded gallery
/// section. `autoDispose` since detail pages are visited transiently,
/// same reasoning as `trekByIdProvider`.
///
/// One-shot fetch rather than `.stream()` — new uploads showing up live
/// is a nice-to-have for browse-then-view content, not worth an open
/// websocket channel per session. Refetches via `ref.invalidate` after
/// an admin's own upload/delete, or the error state's Retry button.
final trekGalleryProvider = FutureProvider.autoDispose.family<List<GalleryMedia>, String>(
  (ref, trekId) => ref.watch(galleryRepositoryProvider).fetchMediaForTrek(trekId),
  name: 'trekGalleryProvider',
);

/// Riverpod AsyncNotifier managing admin gallery mutations (upload,
/// delete). Mirrors TrekAdminController's shape: [state] is shared
/// loading/error status across all actions.
final galleryAdminControllerProvider = AsyncNotifierProvider<GalleryAdminController, void>(
  GalleryAdminController.new,
  name: 'galleryAdminControllerProvider',
);

class GalleryAdminController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<GalleryMedia?> uploadMedia({
    required String trekId,
    required Uint8List bytes,
    required String fileExtension,
    required MediaType mediaType,
    String? caption,
  }) async {
    state = const AsyncLoading();
    GalleryMedia? uploaded;
    state = await AsyncValue.guard(() async {
      uploaded = await ref.read(galleryRepositoryProvider).uploadMedia(
            trekId: trekId,
            bytes: bytes,
            fileExtension: fileExtension,
            mediaType: mediaType,
            caption: caption,
          );
    });
    return uploaded;
  }

  Future<bool> deleteMedia(String id) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      await ref.read(galleryRepositoryProvider).deleteMedia(id);
      success = true;
    });
    return success;
  }
}
