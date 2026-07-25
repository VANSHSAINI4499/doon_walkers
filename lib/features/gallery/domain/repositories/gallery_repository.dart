import 'dart:typed_data';

import 'package:dio/dio.dart' show CancelToken;
import 'package:doon_walkers/features/gallery/domain/entities/gallery_media.dart';

/// Abstract interface for reading and managing gallery media.
///
/// The read methods are safe to call regardless of caller role — RLS
/// (0002_role_policies.sql) already makes `gallery_select` public. The
/// write methods are only ever exposed through admin-gated UI, but RLS
/// enforces the same admin-only rule server-side either way, backed by
/// matching storage.objects policies on the `trek-gallery` bucket
/// (0007_gallery_storage.sql).
abstract class GalleryRepository {
  /// Media for a single trek, newest first — used by the Trek Detail
  /// screen's embedded gallery preview. [limit] caps the fetch (the
  /// preview only ever needs the first 6, not the whole trek).
  ///
  /// One-shot fetch, not a live stream — see [trekGalleryProvider]'s
  /// doc for why this table isn't on Realtime.
  Future<List<GalleryMedia>> fetchMediaForTrek(String trekId, {int? limit});

  /// One page of a trek's media, newest first — backs
  /// [TrekGalleryScreen]'s infinite-scroll masonry grid. `page` is
  /// zero-based; `.range()`-based under the hood.
  Future<List<GalleryMedia>> fetchMediaForTrekPage({
    required String trekId,
    required int page,
    required int pageSize,
  });

  /// Total media count for a trek — drives the preview's "+N · View
  /// All" tile. A head/count query, not a full row fetch.
  Future<int> countForTrek(String trekId);

  /// Uploads [bytes] to the `trek-gallery` bucket under [trekId] and
  /// inserts the corresponding `public.gallery` row. Always uploads to
  /// a fresh, timestamped path — same reasoning as trek cover uploads
  /// in Phase 4 (avoids a stale cached file at a reused path).
  ///
  /// The byte transfer itself goes through [SupabaseStorageUploader]
  /// rather than the plain Supabase storage client, so [onProgress]
  /// reports real byte-level progress and [cancelToken] can genuinely
  /// abort an in-flight upload — both needed by the multi-file upload
  /// sheet's per-item progress bars and cancel buttons.
  ///
  /// [thumbnailBytes] is uploaded as a second object and its URL stored
  /// as `thumbnail_url` — used for videos only (a generated frame);
  /// omit for photos, which render [bytes] itself at a downsized decode
  /// instead. [width]/[height] are the media's (or, for a video, its
  /// thumbnail frame's) pixel dimensions, decoded client-side before
  /// calling this.
  ///
  /// [uploadedAt] lets a batch upload assign a client-side, strictly
  /// increasing timestamp per file *before* dispatching concurrent
  /// uploads, so the feed's order always matches selection order
  /// regardless of which upload happens to finish first. Defaults to
  /// `NOW()` server-side (via omission) for the single-file call sites
  /// that don't care.
  Future<GalleryMedia> uploadMedia({
    required String trekId,
    required Uint8List bytes,
    required String fileExtension,
    required MediaType mediaType,
    String? caption,
    int? width,
    int? height,
    Uint8List? thumbnailBytes,
    DateTime? uploadedAt,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  });

  /// Deletes the gallery row. Best-effort deletes the underlying
  /// Storage object(s) first (see impl) — Storage objects aren't tied
  /// to the row by a DB foreign key, so nothing does this automatically.
  Future<void> deleteMedia(String id);
}
