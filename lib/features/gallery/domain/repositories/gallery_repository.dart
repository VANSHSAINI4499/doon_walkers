import 'dart:typed_data';

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
  /// screen's embedded gallery section.
  ///
  /// One-shot fetch, not a live stream — see [trekGalleryProvider]'s
  /// doc for why this table isn't on Realtime.
  Future<List<GalleryMedia>> fetchMediaForTrek(String trekId);

  /// Uploads [bytes] to the `trek-gallery` bucket under [trekId] and
  /// inserts the corresponding `public.gallery` row. Always uploads to
  /// a fresh, timestamped path — same reasoning as trek cover uploads
  /// in Phase 4 (avoids a stale cached file at a reused path).
  Future<GalleryMedia> uploadMedia({
    required String trekId,
    required Uint8List bytes,
    required String fileExtension,
    required MediaType mediaType,
    String? caption,
  });

  /// Deletes the gallery row. Best-effort deletes the underlying
  /// Storage object first (see impl) — Storage objects aren't tied to
  /// the row by a DB foreign key, so nothing does this automatically.
  Future<void> deleteMedia(String id);
}
