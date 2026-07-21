import 'package:doon_walkers/features/trek_library/data/models/trek_model.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a minimal, otherwise-valid trek with the given [id] and
/// [trekDate] (nullable — omitted entirely, matching how an
/// unscheduled row actually arrives from Postgres).
Trek _trekWithDate(String id, DateTime? date) => TrekModel.fromJson({
      'id': id,
      'title': id,
      'is_published': true,
      'created_at': '2026-01-01T00:00:00.000Z',
      if (date != null) 'trek_date': date.toIso8601String().split('T').first,
    });

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

    test('parses trek_date from a Postgres date string', () {
      final trek = TrekModel.fromJson({...fullJson, 'trek_date': '2026-08-15'});
      expect(trek.trekDate, DateTime(2026, 8, 15));
    });

    test('missing trek_date stays null — existing treks have none set', () {
      final trek = TrekModel.fromJson(fullJson);
      expect(trek.trekDate, isNull);
    });
  });

  group('Trek.isUpcoming / isCompleted', () {
    test('no trek_date is neither upcoming nor completed', () {
      final trek = _trekWithDate('trek-x', null);
      expect(trek.isUpcoming, isFalse);
      expect(trek.isCompleted, isFalse);
    });

    test('a future date is upcoming, not completed', () {
      final trek = _trekWithDate('trek-x', DateTime.now().add(const Duration(days: 10)));
      expect(trek.isUpcoming, isTrue);
      expect(trek.isCompleted, isFalse);
    });

    test('a past date is completed, not upcoming', () {
      final trek = _trekWithDate('trek-x', DateTime.now().subtract(const Duration(days: 10)));
      expect(trek.isUpcoming, isFalse);
      expect(trek.isCompleted, isTrue);
    });

    test('today counts as upcoming, not completed', () {
      // Guards against a naive DateTime comparison misclassifying
      // "today" as past once the clock ticks forward from midnight —
      // isTrekDateBefore must compare by calendar day, not instant.
      final trek = _trekWithDate('trek-x', DateTime.now());
      expect(trek.isUpcoming, isTrue);
      expect(trek.isCompleted, isFalse);
    });
  });

  group('sortTreksForLibrary', () {
    final now = DateTime.now();
    DateTime daysFromNow(int n) => now.add(Duration(days: n));

    test('upcoming treks sort nearest-first (ascending)', () {
      final farUpcoming = _trekWithDate('far', daysFromNow(20));
      final nearUpcoming = _trekWithDate('near', daysFromNow(2));
      final midUpcoming = _trekWithDate('mid', daysFromNow(10));

      final sorted = sortTreksForLibrary([farUpcoming, nearUpcoming, midUpcoming]);

      expect(sorted.map((t) => t.id), ['near', 'mid', 'far']);
    });

    test('completed treks sort most-recently-completed-first (descending)', () {
      final longAgo = _trekWithDate('long-ago', daysFromNow(-30));
      final recent = _trekWithDate('recent', daysFromNow(-2));
      final middling = _trekWithDate('middling', daysFromNow(-10));

      final sorted = sortTreksForLibrary([longAgo, recent, middling]);

      expect(sorted.map((t) => t.id), ['recent', 'middling', 'long-ago']);
    });

    test('unscheduled treks sort after every dated trek, upcoming or completed', () {
      final upcoming = _trekWithDate('upcoming', daysFromNow(5));
      final completed = _trekWithDate('completed', daysFromNow(-5));
      final unscheduledA = _trekWithDate('unscheduled-a', null);
      final unscheduledB = _trekWithDate('unscheduled-b', null);

      final sorted = sortTreksForLibrary([unscheduledA, completed, unscheduledB, upcoming]);

      expect(sorted.map((t) => t.id), ['upcoming', 'completed', 'unscheduled-a', 'unscheduled-b']);
    });

    test('full mix: upcoming (ascending), then completed (descending), then unscheduled', () {
      final treks = [
        _trekWithDate('completed-old', daysFromNow(-40)),
        _trekWithDate('unscheduled', null),
        _trekWithDate('upcoming-far', daysFromNow(30)),
        _trekWithDate('completed-recent', daysFromNow(-3)),
        _trekWithDate('upcoming-near', daysFromNow(1)),
      ];

      final sorted = sortTreksForLibrary(treks);

      expect(sorted.map((t) => t.id), [
        'upcoming-near',
        'upcoming-far',
        'completed-recent',
        'completed-old',
        'unscheduled',
      ]);
    });

    test('an empty list stays empty', () {
      expect(sortTreksForLibrary([]), isEmpty);
    });
  });
}
