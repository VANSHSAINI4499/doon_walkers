import 'package:doon_walkers/features/profile/domain/loyalty_badge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('loyaltyBadgeFor', () {
    test('a brand-new member (0 attended) starts at the bottom rung', () {
      expect(loyaltyBadgeFor(0).name, 'Beginner Explorer');
    });

    test('resolves to the highest rung the attended count clears', () {
      expect(loyaltyBadgeFor(2).name, 'Beginner Explorer');
      expect(loyaltyBadgeFor(3).name, 'Nature Enthusiast');
      expect(loyaltyBadgeFor(5).name, 'Nature Enthusiast');
      expect(loyaltyBadgeFor(6).name, 'Trail Seeker');
      expect(loyaltyBadgeFor(9).name, 'Trail Seeker');
      expect(loyaltyBadgeFor(10).name, 'Mountain Explorer');
      expect(loyaltyBadgeFor(14).name, 'Mountain Explorer');
      expect(loyaltyBadgeFor(15).name, 'Adventure Master');
    });

    test('never regresses past the top rung for very high counts', () {
      expect(loyaltyBadgeFor(1000).name, 'Adventure Master');
    });
  });

  group('nextLoyaltyBadgeAfter', () {
    test('points at the next rung above the current count', () {
      expect(nextLoyaltyBadgeAfter(0)?.name, 'Nature Enthusiast');
      expect(nextLoyaltyBadgeAfter(5)?.name, 'Trail Seeker');
    });

    test('returns null once the top rung is reached', () {
      expect(nextLoyaltyBadgeAfter(15), isNull);
      expect(nextLoyaltyBadgeAfter(1000), isNull);
    });
  });

  test('loyaltyBadgeLadder is sorted ascending by minAttended', () {
    for (var i = 1; i < loyaltyBadgeLadder.length; i++) {
      expect(
        loyaltyBadgeLadder[i].minAttended,
        greaterThan(loyaltyBadgeLadder[i - 1].minAttended),
      );
    }
  });
}
