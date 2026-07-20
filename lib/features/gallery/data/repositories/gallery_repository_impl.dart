import 'dart:typed_data';

import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/gallery/data/models/gallery_media_model.dart';
import 'package:doon_walkers/features/gallery/domain/entities/gallery_media.dart';
import 'package:doon_walkers/features/gallery/domain/repositories/gallery_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Riverpod provider exposing the implementation of [GalleryRepository].
final galleryRepositoryProvider = Provider<GalleryRepository>(
  (ref) => GalleryRepositoryImpl(ref.watch(supabaseClientProvider)),
  name: 'galleryRepositoryProvider',
);

/// Supabase implementation of [GalleryRepository].
class GalleryRepositoryImpl implements GalleryRepository {
  final SupabaseClient _supabase;

  const GalleryRepositoryImpl(this._supabase);

  @override
  Future<List<GalleryMedia>> fetchMediaForTrek(String trekId) async {
    final rows = await _supabase
        .from(AppConstants.tableGallery)
        .select()
        .eq('trek_id', trekId)
        .order('uploaded_at', ascending: false);
    return rows.map(GalleryMediaModel.fromJson).toList();
  }

  @override
  Future<List<GalleryMedia>> fetchAllMedia() async {
    final rows = await _supabase
        .from(AppConstants.tableGallery)
        .select()
        .order('uploaded_at', ascending: false);
    return rows.map(GalleryMediaModel.fromJson).toList();
  }

  @override
  Future<GalleryMedia> uploadMedia({
    required String trekId,
    required Uint8List bytes,
    required String fileExtension,
    required MediaType mediaType,
    String? caption,
  }) async {
    // Always a fresh path, never an overwrite — same reasoning as
    // trek cover uploads (avoids serving a stale cached file at an
    // unchanged URL).
    final path = '$trekId/${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

    await _supabase.storage
        .from(AppConstants.bucketTrekGallery)
        .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: false));

    final url = _supabase.storage.from(AppConstants.bucketTrekGallery).getPublicUrl(path);

    final row = await _supabase
        .from(AppConstants.tableGallery)
        .insert({
          'trek_id': trekId,
          'media_url': url,
          'media_type': mediaType.toDbString(),
          'caption': caption,
        })
        .select()
        .single();

    return GalleryMediaModel.fromJson(row);
  }

  @override
  Future<void> deleteMedia(String id) async {
    // Storage objects aren't tied to the row by a DB foreign key —
    // nothing cascades this automatically, so clean up the object
    // first. Best-effort: a failed cleanup shouldn't block deleting
    // the row itself, it just leaves an orphaned file at worst.
    try {
      final row = await _supabase
          .from(AppConstants.tableGallery)
          .select('media_url')
          .eq('id', id)
          .maybeSingle();
      final mediaUrl = row?['media_url'] as String?;
      if (mediaUrl != null) {
        final path = _extractObjectPath(mediaUrl);
        if (path != null) {
          await _supabase.storage.from(AppConstants.bucketTrekGallery).remove([path]);
        }
      }
    } catch (_) {
      // Orphaned file at worst — not worth failing the delete over.
    }

    await _supabase.from(AppConstants.tableGallery).delete().eq('id', id);
  }

  /// Extracts the object path from a Supabase Storage public URL
  /// (`.../storage/v1/object/public/{bucket}/{path}`). Returns null if
  /// the URL doesn't match that shape — defensive against a malformed
  /// or manually-edited media_url value.
  String? _extractObjectPath(String publicUrl) {
    const marker = '/object/public/${AppConstants.bucketTrekGallery}/';
    final index = publicUrl.indexOf(marker);
    if (index == -1) return null;
    return publicUrl.substring(index + marker.length);
  }
}
