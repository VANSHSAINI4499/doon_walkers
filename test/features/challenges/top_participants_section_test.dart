// Phase 24: coverage for a Phase 21 deliverable (get_challenge_top_
// participants() + its provider) that had zero consuming UI, and zero
// tests, until Phase 23 wired it into Challenge Detail. Mocks the
// provider directly — no real Supabase client.

import 'package:doon_walkers/core/theme/app_theme.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_top_participant.dart';
import 'package:doon_walkers/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/level_badge.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/top_participants_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _challenge = Challenge(
  id: 'c1',
  title: 'Step It Up',
  description: '',
  metric: ChallengeMetric.dailySteps,
  timeWindow: ChallengeTimeWindow.daily,
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
);

Future<void> _pump(
  WidgetTester tester, {
  required List<ChallengeTopParticipant> participants,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        challengeTopParticipantsProvider(
          _challenge.id,
        ).overrideWith((ref) async => participants),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: TopParticipantsSection(challenge: _challenge),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('TopParticipantsSection', () {
    testWidgets('empty list shows the no-one-joined-yet state', (tester) async {
      await _pump(tester, participants: const []);
      expect(
        find.textContaining('No one has joined this challenge yet'),
        findsOneWidget,
      );
    });

    testWidgets(
      'renders display name, level badge, and points chip for each row',
      (tester) async {
        await _pump(
          tester,
          participants: const [
            ChallengeTopParticipant(
              userId: 'u1',
              displayName: 'Asha',
              avatarUrl: null,
              score: 8200,
              totalPoints: 640,
              level: 3,
            ),
            ChallengeTopParticipant(
              userId: 'u2',
              displayName: 'Rohit',
              avatarUrl: 'https://example.com/avatar.png',
              score: 6100,
              totalPoints: 210,
              level: 2,
            ),
          ],
        );

        expect(find.text('Asha'), findsOneWidget);
        expect(find.text('Rohit'), findsOneWidget);
        expect(find.text('640 pts'), findsOneWidget);
        expect(find.text('210 pts'), findsOneWidget);
        expect(find.byType(LevelBadge), findsNWidgets(2));

        final badges =
            tester.widgetList<LevelBadge>(find.byType(LevelBadge)).toList();
        expect(badges.map((b) => b.level), containsAll([3, 2]));
      },
    );

    testWidgets('a participant with no avatar URL falls back to initials', (
      tester,
    ) async {
      await _pump(
        tester,
        participants: const [
          ChallengeTopParticipant(
            userId: 'u1',
            displayName: 'Zara',
            avatarUrl: null,
            score: 100,
            totalPoints: 50,
            level: 1,
          ),
        ],
      );
      // The initials fallback renders the first letter, uppercased.
      expect(find.text('Z'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets(
      'a participant with an avatar URL attempts to render an Image',
      (tester) async {
        await _pump(
          tester,
          participants: const [
            ChallengeTopParticipant(
              userId: 'u1',
              displayName: 'Zara',
              avatarUrl: 'https://example.com/avatar.png',
              score: 100,
              totalPoints: 50,
              level: 1,
            ),
          ],
        );
        expect(find.byType(Image), findsOneWidget);
      },
    );

    testWidgets('shows an error message if the provider fails', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            challengeTopParticipantsProvider(
              _challenge.id,
            ).overrideWith((ref) async => throw Exception('boom')),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: SingleChildScrollView(
                child: TopParticipantsSection(challenge: _challenge),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.textContaining('Could not load participants'),
        findsOneWidget,
      );
    });
  });
}
