import 'package:doon_walkers/features/gallery/domain/entities/gallery_media.dart';

/// Data model representing a row in `public.gallery`, extending
/// [GalleryMedia] with JSON deserialization from a Supabase/PostgREST
/// row.
class GalleryMediaModel extends GalleryMedia {
  const GalleryMediaModel({
    required super.id,
    required super.trekId,
    required super.mediaUrl,
    required super.mediaType,
    super.caption,
    required super.uploadedAt,
  });

  factory GalleryMediaModel.fromJson(Map<String, dynamic> json) {
    return GalleryMediaModel(
      id: json['id'] as String,
      trekId: json['trek_id'] as String,
      mediaUrl: (json['media_url'] as String?) ?? '',
      mediaType: MediaType.fromString(json['media_type'] as String?),
      caption: json['caption'] as String?,
      uploadedAt: json['uploaded_at'] != null
          ? DateTime.parse(json['uploaded_at'] as String)
          : DateTime.now(),
    );
  }
}
