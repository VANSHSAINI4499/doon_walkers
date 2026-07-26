// Phase 24: coverage for the challenge_completed award trigger — zero
// tests existed before or after Phase 23. Exercises the pure
// `triggerChallengeCompletedPointsAward` (extracted from
// ChallengesScreen in Phase 24 for exactly this purpose) against a fake
// gateway — no real Supabase client, no real points_ledger.

import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_progress.dart';
import 'package:doon_walkers/features/challenges/domain/services/challenge_completion_award.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGateway implements ChallengeCompletionAwardGateway {
  final Set<String> alreadyAwardedChallengeIds;
  final List<(String userId, String challengeId, int points)> awardCalls = [];
  final bool throwOnHasAwarded;

  _FakeGateway({
    this.alreadyAwardedChallengeIds = const {},
    this.throwOnHasAwarded = false,
  });

  @override
  Future<bool> hasAwardedChallengeCompleted(String userId, String challengeId) async {
    if (throwOnHasAwarded) throw Exception('boom');
    return alreadyAwardedChallengeIds.contains(challengeId);
  }

  @override
  Future<void> awardChallengeCompleted(
    String userId,
    String challengeId,
    int points,
  ) async {
    awardCalls.add((userId, challengeId, points));
  }
}

Challenge _challenge({String id = 'c1', int pointValue = 75}) => Challenge(
  id: id,
  title: 'Step It Up',
  description: '',
  metric: ChallengeMetric.dailySteps,
  timeWindow: ChallengeTimeWindow.daily,
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
  pointValue: pointValue,
);

ChallengeProgress _progress({
  String challengeId = 'c1',
  ChallengeTier? tier,
  double value = 100,
}) => ChallengeProgress(challengeId: challengeId, currentValue: value, currentTier: tier);

void main() {
  group('triggerChallengeCompletedPointsAward', () {
    test('awards once when enrolled, platinum, and never awarded before', () async {
      final gateway = _FakeGateway();
      await triggerChallengeCompletedPointsAward(
        userId: 'u1',
        challenges: [_challenge()],
        progressList: [_progress(tier: ChallengeTier.platinum)],
        enrolledChallengeIds: {'c1'},
        gateway: gateway,
      );

      expect(gateway.awardCalls, [('u1', 'c1', 75)]);
    });

    test('does NOT award when currentTier is below platinum', () async {
      for (final tier in [ChallengeTier.bronze, ChallengeTier.silver, ChallengeTier.gold, null]) {
        final gateway = _FakeGateway();
        await triggerChallengeCompletedPointsAward(
          userId: 'u1',
          challenges: [_challenge()],
          progressList: [_progress(tier: tier)],
          enrolledChallengeIds: {'c1'},
          gateway: gateway,
        );
        expect(gateway.awardCalls, isEmpty, reason: 'tier=$tier should not award');
      }
    });

    test('does NOT award when the user is not enrolled, even at platinum', () async {
      final gateway = _FakeGateway();
      await triggerChallengeCompletedPointsAward(
        userId: 'u1',
        challenges: [_challenge()],
        progressList: [_progress(tier: ChallengeTier.platinum)],
        enrolledChallengeIds: const {}, // not enrolled in c1
        gateway: gateway,
      );
      expect(gateway.awardCalls, isEmpty);
    });

    test('does NOT award when a challenge_completed ledger entry already exists', () async {
      final gateway = _FakeGateway(alreadyAwardedChallengeIds: {'c1'});
      await triggerChallengeCompletedPointsAward(
        userId: 'u1',
        challenges: [_challenge()],
        progressList: [_progress(tier: ChallengeTier.platinum)],
        enrolledChallengeIds: {'c1'},
        gateway: gateway,
      );
      expect(gateway.awardCalls, isEmpty);
    });

    test('a ledger-check failure is swallowed, not propagated, and does not award', () async {
      final gateway = _FakeGateway(throwOnHasAwarded: true);
      await expectLater(
        triggerChallengeCompletedPointsAward(
          userId: 'u1',
          challenges: [_challenge()],
          progressList: [_progress(tier: ChallengeTier.platinum)],
          enrolledChallengeIds: {'c1'},
          gateway: gateway,
        ),
        completes,
      );
      expect(gateway.awardCalls, isEmpty);
    });

    test('checks each qualifying challenge independently — one already-awarded does not block another', () async {
      final gateway = _FakeGateway(alreadyAwardedChallengeIds: {'c1'});
      await triggerChallengeCompletedPointsAward(
        userId: 'u1',
        challenges: [_challenge(id: 'c1', pointValue: 50), _challenge(id: 'c2', pointValue: 75)],
        progressList: [
          _progress(challengeId: 'c1', tier: ChallengeTier.platinum),
          _progress(challengeId: 'c2', tier: ChallengeTier.platinum),
        ],
        enrolledChallengeIds: {'c1', 'c2'},
        gateway: gateway,
      );
      expect(gateway.awardCalls, [('u1', 'c2', 75)]);
    });

    test('ignores progress rows for challenges not present in the challenges list', () async {
      final gateway = _FakeGateway();
      await triggerChallengeCompletedPointsAward(
        userId: 'u1',
        challenges: const [], // c1 missing entirely
        progressList: [_progress(tier: ChallengeTier.platinum)],
        enrolledChallengeIds: {'c1'},
        gateway: gateway,
      );
      expect(gateway.awardCalls, isEmpty);
    });
  });
}
