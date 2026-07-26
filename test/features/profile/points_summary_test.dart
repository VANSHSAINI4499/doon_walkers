// PointsSummary.progressToNextLevel normalizes "total vs next threshold"
// down to "how far through the CURRENT level" — the only nontrivial math
// added on the Dart side for Phase 22 (everything else defers to the
// get_my_points_summary() RPC). The ladder values here mirror
// level_for_points()/points_for_level() in
// 0039_points_history_and_enrollment_fix.sql: 0, 500, 1500, 3000, 5000,
// 7500, 10000, 15000 for levels 1..8.

import 'package:doon_walkers/features/profile/domain/entities/points_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PointsSummary.progressToNextLevel', () {
    test('freshly at a level floor is 0% through it', () {
      const summary = PointsSummary(
        totalPoints: 500,
        level: 2,
        currentLevelFloor: 500,
        nextLevel: 3,
        pointsToNextLevel: 1000, // 1500 - 500
        isMaxLevel: false,
      );
      expect(summary.progressToNextLevel, 0.0);
    });

    test('halfway through a level reads 0.5', () {
      // Level 2 spans 500..1500 (1000 points wide). 1000 is the midpoint.
      const summary = PointsSummary(
        totalPoints: 1000,
        level: 2,
        currentLevelFloor: 500,
        nextLevel: 3,
        pointsToNextLevel: 500, // 1500 - 1000
        isMaxLevel: false,
      );
      expect(summary.progressToNextLevel, 0.5);
    });

    test('one point before the next threshold is nearly 1.0', () {
      const summary = PointsSummary(
        totalPoints: 1499,
        level: 2,
        currentLevelFloor: 500,
        nextLevel: 3,
        pointsToNextLevel: 1,
        isMaxLevel: false,
      );
      expect(summary.progressToNextLevel, closeTo(0.999, 0.001));
    });

    test('max level (8) always reads 1.0 regardless of total', () {
      const summary = PointsSummary(
        totalPoints: 50000,
        level: 8,
        currentLevelFloor: 15000,
        nextLevel: null,
        pointsToNextLevel: null,
        isMaxLevel: true,
      );
      expect(summary.progressToNextLevel, 1.0);
    });

    test('a brand-new member (0 points, level 1) reads 0.0', () {
      const summary = PointsSummary(
        totalPoints: 0,
        level: 1,
        currentLevelFloor: 0,
        nextLevel: 2,
        pointsToNextLevel: 500,
        isMaxLevel: false,
      );
      expect(summary.progressToNextLevel, 0.0);
    });

    test('PointsSummary.guest is internally consistent (0.0 progress)', () {
      expect(PointsSummary.guest.progressToNextLevel, 0.0);
    });

    test('fromRow parses a get_my_points_summary() row', () {
      final summary = PointsSummary.fromRow(const {
        'total_points': 1000,
        'level': 2,
        'current_level_floor': 500,
        'next_level': 3,
        'points_to_next_level': 500,
        'is_max_level': false,
      });
      expect(summary.totalPoints, 1000);
      expect(summary.level, 2);
      expect(summary.progressToNextLevel, 0.5);
    });

    test('fromRow handles a max-level row (nulls for next-level fields)', () {
      final summary = PointsSummary.fromRow(const {
        'total_points': 20000,
        'level': 8,
        'current_level_floor': 15000,
        'next_level': null,
        'points_to_next_level': null,
        'is_max_level': true,
      });
      expect(summary.isMaxLevel, isTrue);
      expect(summary.nextLevel, isNull);
      expect(summary.progressToNextLevel, 1.0);
    });
  });
}
