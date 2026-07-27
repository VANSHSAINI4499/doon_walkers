import 'dart:typed_data';

import 'package:dio/dio.dart' show CancelToken;
import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/gallery/data/models/gallery_media_model.dart';
import 'package:doon_walkers/features/gallery/data/services/supabase_storage_uploader.dart';
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
  final SupabaseStorageUploader _uploader = SupabaseStorageUploader();

  GalleryRepositoryImpl(this._supabase);

  @override
  Future<List<GalleryMedia>> fetchMediaForTrek(
    String trekId, {
    int? limit,
  }) async {
    final query = _supabase
        .from(AppConstants.tableGallery)
        .select()
        .eq('trek_id', trekId)
        .order('uploaded_at', ascending: false);
    final rows = limit != null ? await query.limit(limit) : await query;
    return rows.map(GalleryMediaModel.fromJson).toList();
  }

  @override
  Future<List<GalleryMedia>> fetchMediaForTrekPage({
    required String trekId,
    required int page,
    required int pageSize,
  }) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;
    final rows = await _supabase
        .from(AppConstants.tableGallery)
        .select()
        .eq('trek_id', trekId)
        .order('uploaded_at', ascending: false)
        .range(from, to);
    return rows.map(GalleryMediaModel.fromJson).toList();
  }

  @override
  Future<int> countForTrek(String trekId) async {
    final response = await _supabase
        .from(AppConstants.tableGallery)
        .count(CountOption.exact)
        .eq('trek_id', trekId);
    return response;
  }

  @override
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
  }) async {
    // Always a fresh path, never an overwrite — same reasoning as
    // trek cover uploads (avoids serving a stale cached file at an
    // unchanged URL).
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '$trekId/$timestamp.$fileExtension';

    // Thumbnail (videos only) is a small file uploaded first — weighted
    // 15% of the overall task, the main asset the remaining 85%, so a
    // caller-supplied onProgress reads as one continuous bar rather than
    // jumping backwards when the second upload starts.
    String? thumbnailUrl;
    if (thumbnailBytes != null) {
      final thumbPath = '$trekId/${timestamp}_thumb.jpg';
      thumbnailUrl = await _uploader.upload(
        bucket: AppConstants.bucketTrekGallery,
        path: thumbPath,
        bytes: thumbnailBytes,
        fileExtension: 'jpg',
        cancelToken: cancelToken,
        onProgress: onProgress == null ? null : (p) => onProgress(p * 0.15),
      );
    }

    final url = await _uploader.upload(
      bucket: AppConstants.bucketTrekGallery,
      path: path,
      bytes: bytes,
      fileExtension: fileExtension,
      cancelToken: cancelToken,
      onProgress:
          onProgress == null
              ? null
              : (p) => onProgress(thumbnailBytes != null ? 0.15 + p * 0.85 : p),
    );

    final row =
        await _supabase
            .from(AppConstants.tableGallery)
            .insert({
              'trek_id': trekId,
              'media_url': url,
              'media_type': mediaType.toDbString(),
              'caption': caption,
              if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
              if (width != null) 'width': width,
              if (height != null) 'height': height,
              if (uploadedAt != null)
                'uploaded_at': uploadedAt.toIso8601String(),
            })
            .select()
            .single();

    return GalleryMediaModel.fromJson(row);
  }

  @override
  Future<void> deleteMedia(String id) async {
    // Storage objects aren't tied to the row by a DB foreign key —
    // nothing cascades this automatically, so clean up the object(s)
    // first. Best-effort: a failed cleanup shouldn't block deleting
    // the row itself, it just leaves an orphaned file at worst.
    try {
      final row =
          await _supabase
              .from(AppConstants.tableGallery)
              .select('media_url, thumbnail_url')
              .eq('id', id)
              .maybeSingle();
      final mediaUrl = row?['media_url'] as String?;
      final thumbnailUrl = row?['thumbnail_url'] as String?;
      final paths =
          [
            if (mediaUrl != null) _extractObjectPath(mediaUrl),
            if (thumbnailUrl != null) _extractObjectPath(thumbnailUrl),
          ].whereType<String>().toList();
      if (paths.isNotEmpty) {
        await _supabase.storage
            .from(AppConstants.bucketTrekGallery)
            .remove(paths);
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
