import 'package:doon_walkers/features/trek_library/data/models/trek_model.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrekDifficulty', () {
    test('fromString round-trips every enum value through toDbString', () {
      for (final difficulty in TrekDifficulty.values) {
        expect(TrekDifficulty.fromString(difficulty.toDbString()), difficulty);
      }
    });

    test('unknown or null values fall back to moderate (matches DB default)', () {
      expect(TrekDifficulty.fromString('legendary'), TrekDifficulty.moderate);
      expect(TrekDifficulty.fromString(null), TrekDifficulty.moderate);
    });
  });

  group('TrekModel.fromJson', () {
    final fullJson = {
      'id': 'trek-1',
      'title': 'Kedarkantha Trek',
      'description': 'A snowy winter trek in Uttarakhand.',
      'difficulty': 'moderate',
      'distance_km': 20.5,
      'duration_days': 6,
      'altitude_m': 3810,
      'best_season': 'Dec – Apr',
      'things_to_carry': 'Warm jacket, trekking shoes',
      'google_map_link': 'https://maps.app.goo.gl/example',
      'cover_image': 'https://project.supabase.co/storage/v1/object/public/trek-covers/trek-1/1.jpg',
      'is_published': true,
      'created_at': '2026-01-15T10:00:00.000Z',
    };

    test('parses every field from a full row', () {
      final trek = TrekModel.fromJson(fullJson);

      expect(trek.id, 'trek-1');
      expect(trek.title, 'Kedarkantha Trek');
      expect(trek.difficulty, TrekDifficulty.moderate);
      expect(trek.distanceKm, 20.5);
      expect(trek.durationDays, 6);
      expect(trek.altitudeM, 3810);
      expect(trek.bestSeason, 'Dec – Apr');
      expect(trek.thingsToCarry, 'Warm jacket, trekking shoes');
      expect(trek.googleMapLink, 'https://maps.app.goo.gl/example');
      expect(trek.coverImage, isNotNull);
      expect(trek.isPublished, isTrue);
      expect(trek.createdAt, DateTime.parse('2026-01-15T10:00:00.000Z'));
    });

    test('a draft trek with only required fields parses without throwing', () {
      final trek = TrekModel.fromJson({
        'id': 'trek-2',
        'title': 'New Draft Trek',
        'difficulty': 'easy',
        'is_published': false,
        'created_at': '2026-02-01T00:00:00.000Z',
      });

      expect(trek.title, 'New Draft Trek');
      expect(trek.description, ''); // no 'description' key at all
      expect(trek.distanceKm, isNull);
      expect(trek.durationDays, isNull);
      expect(trek.altitudeM, isNull);
      expect(trek.bestSeason, isNull);
      expect(trek.coverImage, isNull);
      expect(trek.isPublished, isFalse);
    });

    test('missing is_published defaults to false, not true', () {
      final trek = TrekModel.fromJson({
        'id': 'trek-3',
        'title': 'Untitled',
        'created_at': '2026-02-01T00:00:00.000Z',
      });

      expect(trek.isPublished, isFalse);
    });
  });
}
