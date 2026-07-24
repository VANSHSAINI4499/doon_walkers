// Guards ChallengeCard / ChallengeProgressBar state branching across the
// Phase 4 redesign — WHICH of {draft copy, guest sign-in prompt, progress
// bar} shows, and what the progress bar reads, must be unchanged. The
// progress/tier maths lives in ChallengeProgressBar and is exercised here
// through the card's rendered text.

import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/core/theme/app_theme.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_progress.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/challenge_card.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/tier_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Challenge _challenge({bool active = true}) => Challenge(
  id: 'c1',
  title: 'Step It Up',
  description: 'Walk more every day.',
  metric: ChallengeMetric.dailySteps,
  timeWindow: ChallengeTimeWindow.daily,
  isActive: active,
  createdAt: DateTime(2026, 1, 1),
  tiers: const [
    ChallengeTierThreshold(id: 't1', challengeId: 'c1', tier: ChallengeTier.bronze, thresholdValue: 100),
    ChallengeTierThreshold(id: 't2', challengeId: 'c1', tier: ChallengeTier.silver, thresholdValue: 200),
    ChallengeTierThreshold(id: 't3', challengeId: 'c1', tier: ChallengeTier.gold, thresholdValue: 300),
    ChallengeTierThreshold(id: 't4', challengeId: 'c1', tier: ChallengeTier.platinum, thresholdValue: 400),
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  required Challenge challenge,
  required bool signedIn,
  ChallengeProgress? progress,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [isSignedInProvider.overrideWith((ref) => signedIn)],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChallengeCard(challenge: challenge, progress: progress, onTap: () {}),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  // Let the progress bar's TweenAnimationBuilder settle onto its value.
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('ChallengeCard state branching', () {
    testWidgets('guest sees the sign-in prompt, not a progress bar', (tester) async {
      await _pump(tester, challenge: _challenge(), signedIn: false);
      expect(find.text('Sign in to track your progress'), findsOneWidget);
      expect(find.textContaining('to Bronze'), findsNothing);
    });

    testWidgets('draft challenge shows the not-visible copy, no prompt/bar', (tester) async {
      await _pump(tester, challenge: _challenge(active: false), signedIn: true);
      expect(find.text('Not visible to members yet.'), findsOneWidget);
      expect(find.text('Sign in to track your progress'), findsNothing);
      // No progress bar rendered for a draft.
      expect(find.textContaining('to Bronze'), findsNothing);
    });

    testWidgets('signed-in with no progress → 0 toward Bronze', (tester) async {
      await _pump(tester, challenge: _challenge(), signedIn: true, progress: null);
      expect(find.textContaining('to Bronze'), findsOneWidget);
      expect(find.text('Sign in to track your progress'), findsNothing);
    });

    testWidgets('signed-in at Bronze → progress toward Silver + a tier badge', (tester) async {
      await _pump(
        tester,
        challenge: _challenge(),
        signedIn: true,
        progress: const ChallengeProgress(challengeId: 'c1', currentValue: 150, currentTier: ChallengeTier.bronze),
      );
      expect(find.textContaining('to Silver'), findsOneWidget);
      expect(find.byType(TierBadgeIcon), findsWidgets);
    });

    testWidgets('platinum shows the max-tier state, not another bar', (tester) async {
      await _pump(
        tester,
        challenge: _challenge(),
        signedIn: true,
        progress: const ChallengeProgress(challengeId: 'c1', currentValue: 500, currentTier: ChallengeTier.platinum),
      );
      expect(find.text('Platinum reached — the top tier!'), findsOneWidget);
      expect(find.textContaining('to Silver'), findsNothing);
    });
  });

  group('TierBadge palette (Phase 4 mapping)', () {
    test('gold maps to the brand gold and platinum to sky blue', () {
      expect(TierBadge.colorFor(ChallengeTier.gold), const Color(0xFFFFD54F));
      expect(TierBadge.colorFor(ChallengeTier.platinum), const Color(0xFF38BDF8));
    });

    test('all four tiers have distinct colours', () {
      final colors = ChallengeTier.values.map(TierBadge.colorFor).toSet();
      expect(colors.length, 4);
    });
  });
}
