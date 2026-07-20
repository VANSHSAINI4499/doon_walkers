import 'package:doon_walkers/features/gallery/data/models/gallery_media_model.dart';
import 'package:doon_walkers/features/gallery/domain/entities/gallery_media.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MediaType', () {
    test('fromString round-trips every enum value through toDbString', () {
      for (final type in MediaType.values) {
        expect(MediaType.fromString(type.toDbString()), type);
      }
    });

    test('unknown or null values fall back to photo (matches DB default)', () {
      expect(MediaType.fromString('gif'), MediaType.photo);
      expect(MediaType.fromString(null), MediaType.photo);
    });

    test('fromExtension detects photo extensions', () {
      expect(MediaType.fromExtension('jpg'), MediaType.photo);
      expect(MediaType.fromExtension('JPEG'), MediaType.photo);
      expect(MediaType.fromExtension('png'), MediaType.photo);
      expect(MediaType.fromExtension('webp'), MediaType.photo);
    });

    test('fromExtension detects video extensions', () {
      expect(MediaType.fromExtension('mp4'), MediaType.video);
      expect(MediaType.fromExtension('MOV'), MediaType.video);
      expect(MediaType.fromExtension('webm'), MediaType.video);
    });

    test('fromExtension returns null for an unsupported extension', () {
      expect(MediaType.fromExtension('gif'), isNull);
      expect(MediaType.fromExtension(''), isNull);
    });
  });

  group('GalleryMediaModel.fromJson', () {
    final fullJson = {
      'id': 'media-1',
      'trek_id': 'trek-1',
      'media_url': 'https://project.supabase.co/storage/v1/object/public/trek-gallery/trek-1/1.jpg',
      'media_type': 'photo',
      'caption': 'Sunrise from base camp',
      'uploaded_at': '2026-07-19T21:10:54.000Z',
    };

    test('parses every field from a full row', () {
      final media = GalleryMediaModel.fromJson(fullJson);

      expect(media.id, 'media-1');
      expect(media.trekId, 'trek-1');
      expect(media.mediaUrl, isNotEmpty);
      expect(media.mediaType, MediaType.photo);
      expect(media.caption, 'Sunrise from base camp');
      expect(media.uploadedAt, DateTime.parse('2026-07-19T21:10:54.000Z'));
    });

    test('a video row with no caption parses without throwing', () {
      final media = GalleryMediaModel.fromJson({
        'id': 'media-2',
        'trek_id': 'trek-1',
        'media_url': 'https://project.supabase.co/storage/v1/object/public/trek-gallery/trek-1/2.mp4',
        'media_type': 'video',
        'uploaded_at': '2026-07-19T21:10:54.000Z',
      });

      expect(media.mediaType, MediaType.video);
      expect(media.caption, isNull);
    });

    test('missing media_type defaults to photo, not throws', () {
      final media = GalleryMediaModel.fromJson({
        'id': 'media-3',
        'trek_id': 'trek-1',
        'media_url': 'https://example.com/x.jpg',
        'uploaded_at': '2026-07-19T21:10:54.000Z',
      });

      expect(media.mediaType, MediaType.photo);
    });
  });
}
