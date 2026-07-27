import 'dart:async';

import 'package:doon_walkers/features/gallery/data/repositories/gallery_repository_impl.dart';
import 'package:doon_walkers/features/gallery/domain/entities/gallery_media.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The trek-detail preview's first 5 items (newest first) — Trek
/// Detail screen's embedded [TrekGalleryPreview]. `autoDispose` since
/// detail pages are visited transiently, same reasoning as
/// `trekByIdProvider`.
///
/// One-shot fetch rather than `.stream()` — new uploads showing up live
/// is a nice-to-have for browse-then-view content, not worth an open
/// websocket channel per session. Refetches via `ref.invalidate` after
/// an admin's own upload/delete, or the error state's Retry button.
final trekGalleryProvider = FutureProvider.autoDispose
    .family<List<GalleryMedia>, String>(
      (ref, trekId) => ref
          .watch(galleryRepositoryProvider)
          .fetchMediaForTrek(trekId, limit: 5),
      name: 'trekGalleryProvider',
    );

/// Total media count for a trek — drives [TrekGalleryPreview]'s
/// "+N · View All" tile once there are more than 5 items.
final trekGalleryCountProvider = FutureProvider.autoDispose.family<int, String>(
  (ref, trekId) => ref.watch(galleryRepositoryProvider).countForTrek(trekId),
  name: 'trekGalleryCountProvider',
);

/// Riverpod AsyncNotifier managing admin gallery deletes. Uploads go
/// through [MediaUploadController]/[MediaUploadService] instead (the
/// multi-file batch upload path) — this controller is delete-only now.
/// [state] is shared loading/error status across calls, same shape as
/// TrekAdminController.
final galleryAdminControllerProvider =
    AsyncNotifierProvider<GalleryAdminController, void>(
      GalleryAdminController.new,
      name: 'galleryAdminControllerProvider',
    );

class GalleryAdminController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

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
