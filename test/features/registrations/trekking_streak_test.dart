import 'package:doon_walkers/features/registrations/data/models/trekking_streak_model.dart';
import 'package:doon_walkers/features/registrations/domain/entities/trekking_streak.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrekkingStreakModel.fromJson', () {
    test('parses the get_my_streak() RPC row', () {
      final streak = TrekkingStreakModel.fromJson({
        'current_streak_months': 2,
        'longest_streak_months': 5,
      });

      expect(streak.currentMonths, 2);
      expect(streak.longestMonths, 5);
    });

    test('missing fields default to 0 instead of throwing', () {
      final streak = TrekkingStreakModel.fromJson({});

      expect(streak.currentMonths, 0);
      expect(streak.longestMonths, 0);
    });
  });

  group('TrekkingStreak.isActive', () {
    test('a positive current streak is active', () {
      expect(const TrekkingStreak(currentMonths: 1, longestMonths: 3).isActive, isTrue);
    });

    test('a broken streak (current 0) is not active, even with history', () {
      expect(const TrekkingStreak(currentMonths: 0, longestMonths: 3).isActive, isFalse);
    });

    test('TrekkingStreak.zero is not active', () {
      expect(TrekkingStreak.zero.isActive, isFalse);
    });
  });
}
