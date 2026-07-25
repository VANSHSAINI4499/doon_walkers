/// Maps 1-to-1 with the `media_type` enum in Postgres (`photo`, `video`)
/// — see 0001_baseline_schema.sql.
enum MediaType {
  photo,
  video;

  /// Matches the Dart enum's identifier name exactly to the Postgres
  /// enum value — deliberately kept 1:1 so `.name` round-trips safely.
  static MediaType fromString(String? value) {
    return MediaType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => MediaType.photo, // matches the DB column default
    );
  }

  String toDbString() => name;

  /// Extensions accepted for each media type — used both to validate a
  /// picked file client-side and to auto-detect [MediaType] from it
  /// without asking the admin to choose manually.
  static const Set<String> photoExtensions = {'jpg', 'jpeg', 'png', 'webp'};
  static const Set<String> videoExtensions = {'mp4', 'mov', 'webm'};

  /// Returns the [MediaType] a file extension belongs to, or `null` if
  /// it isn't one of the extensions the trek-gallery bucket accepts.
  static MediaType? fromExtension(String extension) {
    final ext = extension.toLowerCase();
    if (photoExtensions.contains(ext)) return MediaType.photo;
    if (videoExtensions.contains(ext)) return MediaType.video;
    return null;
  }
}

/// Core domain representation of a row in `public.gallery`.
class GalleryMedia {
  final String id;
  final String trekId;
  final String mediaUrl;
  final MediaType mediaType;
  final String? caption;
  final DateTime uploadedAt;

  /// A generated JPEG frame for a video (0032_gallery_media_metadata.sql)
  /// — always null for a photo, which renders [mediaUrl] itself at a
  /// downsized decode instead (see MediaCacheManager). Null for videos
  /// uploaded before this migration too — [VideoThumbnailWidget] falls
  /// back to a themed placeholder rather than a blank tile in that case.
  final String? thumbnailUrl;

  /// The media's pixel dimensions — for a video, its [thumbnailUrl]
  /// frame's dimensions. Decoded client-side at upload time. Null for
  /// rows uploaded before this migration; [aspectRatio] falls back to
  /// a square tile for those instead of erroring.
  final int? width;
  final int? height;

  const GalleryMedia({
    required this.id,
    required this.trekId,
    required this.mediaUrl,
    required this.mediaType,
    this.caption,
    required this.uploadedAt,
    this.thumbnailUrl,
    this.width,
    this.height,
  });

  /// Drives the masonry grid's per-tile aspect ratio. Clamped so a
  /// panorama or a very tall portrait can't blow a single tile out to
  /// dominate a whole column — 0.55 (tall) .. 1.9 (wide) keeps every
  /// tile within a Pinterest-like range. Falls back to a square tile
  /// when dimensions aren't known (pre-migration rows).
  double get aspectRatio {
    final w = width;
    final h = height;
    if (w == null || h == null || h == 0) return 1.0;
    return (w / h).clamp(0.55, 1.9).toDouble();
  }
}
