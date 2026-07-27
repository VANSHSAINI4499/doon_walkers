import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:doon_walkers/core/config/env_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Uploads a file to Supabase Storage over a raw `PUT`, replicating
/// exactly what `supabase_flutter`'s `StorageFileApi.uploadBinary` does
/// over HTTP — same endpoint, same headers — but via [Dio] so the
/// upload gets real byte-level [onProgress] callbacks and a genuine
/// [CancelToken]-based abort, neither of which the bundled storage
/// client exposes.
///
/// Used by [GalleryRepositoryImpl.uploadMedia] for both the main media
/// file and (for videos) the generated thumbnail — the multi-file
/// upload sheet's per-item progress bars and cancel buttons depend on
/// this, not on the plain storage client.
class SupabaseStorageUploader {
  SupabaseStorageUploader({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  /// Extensions this bucket accepts, mapped to the MIME type Storage's
  /// `allowed_mime_types` (0007_gallery_storage.sql) checks — kept in
  /// sync with [MediaType.photoExtensions]/[videoExtensions].
  static const Map<String, String> _mimeTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    'webm': 'video/webm',
  };

  static String mimeTypeFor(String fileExtension) =>
      _mimeTypes[fileExtension.toLowerCase()] ?? 'application/octet-stream';

  /// Uploads [bytes] to `{bucket}/{path}` and returns the object's
  /// public URL. Throws [DioException] with `type ==
  /// DioExceptionType.cancel` if [cancelToken] was cancelled mid-flight
  /// — callers distinguish that from a genuine failure.
  Future<String> upload({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String fileExtension,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final session = Supabase.instance.client.auth.currentSession;
    final url = '${EnvConfig.supabaseUrl}/storage/v1/object/$bucket/$path';

    await _dio.put<void>(
      url,
      data: bytes,
      options: Options(
        headers: {
          'Authorization':
              'Bearer ${session?.accessToken ?? EnvConfig.supabaseAnonKey}',
          'apikey': EnvConfig.supabaseAnonKey,
          'Content-Length': bytes.length.toString(),
          'x-upsert': 'false',
        },
        contentType: mimeTypeFor(fileExtension),
      ),
      onSendProgress:
          onProgress == null
              ? null
              : (sent, total) {
                if (total > 0) onProgress(sent / total);
              },
      cancelToken: cancelToken,
    );

    return Supabase.instance.client.storage.from(bucket).getPublicUrl(path);
  }
}
