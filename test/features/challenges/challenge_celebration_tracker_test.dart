import 'package:doon_walkers/features/challenges/data/services/challenge_celebration_tracker.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isNewlyAchievedTier', () {
    test('never celebrates with no prior baseline, even a real first tier', () {
      expect(
        isNewlyAchievedTier(hadBaseline: false, previous: null, current: ChallengeTier.bronze),
        isFalse,
      );
    });

    test('never celebrates when still below bronze', () {
      expect(
        isNewlyAchievedTier(hadBaseline: true, previous: null, current: null),
        isFalse,
      );
    });

    test('celebrates a confirmed-zero baseline crossing into bronze', () {
      expect(
        isNewlyAchievedTier(hadBaseline: true, previous: null, current: ChallengeTier.bronze),
        isTrue,
      );
    });

    test('celebrates a real tier increase', () {
      expect(
        isNewlyAchievedTier(
          hadBaseline: true,
          previous: ChallengeTier.bronze,
          current: ChallengeTier.silver,
        ),
        isTrue,
      );
    });

    test('does not celebrate an unchanged tier', () {
      expect(
        isNewlyAchievedTier(
          hadBaseline: true,
          previous: ChallengeTier.gold,
          current: ChallengeTier.gold,
        ),
        isFalse,
      );
    });

    test('does not celebrate a decrease (defensive — the RPC never actually regresses)', () {
      expect(
        isNewlyAchievedTier(
          hadBaseline: true,
          previous: ChallengeTier.platinum,
          current: ChallengeTier.gold,
        ),
        isFalse,
      );
    });
  });
}
