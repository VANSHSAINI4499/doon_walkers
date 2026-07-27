import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Trek Calendar & Date Window Tests', () {
    final start = DateTime(2026, 8, 10);
    final singleDayTrek = Trek(
      id: 'trk-001',
      title: 'Nag Tibba Day Trek',
      description: 'Scenic day trek',
      difficulty: TrekDifficulty.easy,
      isPublished: true,
      createdAt: DateTime.now(),
      trekDate: start,
      durationDays: 1,
    );

    final multiDayTrek = Trek(
      id: 'trk-002',
      title: 'Kedarkantha Winter Expedition',
      description: '4 day summit trek',
      difficulty: TrekDifficulty.hard,
      isPublished: true,
      createdAt: DateTime.now(),
      trekDate: start,
      durationDays: 4,
    );

    test('Single-day trek starts and ends on same date', () {
      final trekStart = singleDayTrek.trekDate!;
      final duration = singleDayTrek.durationDays ?? 1;
      final trekEnd = trekStart.add(Duration(days: duration - 1));

      expect(trekStart, DateTime(2026, 8, 10));
      expect(trekEnd, DateTime(2026, 8, 10));
    });

    test('Multi-day trek correctly spans durationDays', () {
      final trekStart = multiDayTrek.trekDate!;
      final duration = multiDayTrek.durationDays ?? 1;
      final trekEnd = trekStart.add(Duration(days: duration - 1));

      expect(trekStart, DateTime(2026, 8, 10));
      expect(trekEnd, DateTime(2026, 8, 13));
    });

    test('TrekDifficulty labels round-trip correctly', () {
      expect(TrekDifficulty.easy.label, 'Easy');
      expect(TrekDifficulty.moderate.label, 'Moderate');
      expect(TrekDifficulty.hard.label, 'Hard');
      expect(TrekDifficulty.extreme.label, 'Extreme');
    });
  });
}
