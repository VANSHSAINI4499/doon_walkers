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

  const GalleryMedia({
    required this.id,
    required this.trekId,
    required this.mediaUrl,
    required this.mediaType,
    this.caption,
    required this.uploadedAt,
  });
}
