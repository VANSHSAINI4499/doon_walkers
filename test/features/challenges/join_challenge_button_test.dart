// Phase 24: coverage for a Phase 21 deliverable that had zero tests
// before or after Phase 23 — button label/state across not-enrolled,
// enrolled, and ended, plus that tapping actually calls the
// enroll/unenroll controller. Everything is mocked; nothing here
// touches a real Supabase client.

import 'dart:async';

import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/core/theme/app_theme.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/join_challenge_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Challenge _challenge({
  ChallengeTimeWindow timeWindow = ChallengeTimeWindow.daily,
  DateTime? endDate,
}) => Challenge(
  id: 'c1',
  title: 'Step It Up',
  description: '',
  metric: ChallengeMetric.dailySteps,
  timeWindow: timeWindow,
  endDate: endDate,
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
);

class _FakeEnrollmentController extends EnrollmentController {
  bool enrollCalled = false;
  bool unenrollCalled = false;
  bool result = true;

  @override
  FutureOr<void> build() {}

  @override
  Future<bool> enroll(String challengeId) async {
    enrollCalled = true;
    return result;
  }

  @override
  Future<bool> unenroll(String challengeId) async {
    unenrollCalled = true;
    return result;
  }
}

Future<_FakeEnrollmentController> _pump(
  WidgetTester tester, {
  required Challenge challenge,
  required bool enrolled,
  bool signedIn = true,
}) async {
  final fake = _FakeEnrollmentController();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        isSignedInProvider.overrideWith((ref) => signedIn),
        challengeEnrollmentStatusProvider(
          challenge.id,
        ).overrideWith((ref) async => enrolled),
        enrollmentControllerProvider.overrideWith(() => fake),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: JoinChallengeButton(challenge: challenge)),
      ),
    ),
  );
  await tester.pump();
  return fake;
}

void main() {
  group('JoinChallengeButton state', () {
    testWidgets('not enrolled shows Coming Soon, disabled', (tester) async {
      await _pump(tester, challenge: _challenge(), enrolled: false);
      expect(find.text('Coming Soon'), findsOneWidget);
      expect(find.text('Leave Challenge'), findsNothing);
      expect(find.text('Challenge Ended'), findsNothing);
    });

    testWidgets('enrolled shows Leave Challenge', (tester) async {
      await _pump(tester, challenge: _challenge(), enrolled: true);
      expect(find.text('Leave Challenge'), findsOneWidget);
      expect(find.text('Join Challenge'), findsNothing);
    });

    testWidgets(
      'an ended (past end date) custom-range challenge shows Challenge Ended, disabled',
      (tester) async {
        await _pump(
          tester,
          challenge: _challenge(
            timeWindow: ChallengeTimeWindow.customRange,
            endDate: DateTime.now().subtract(const Duration(days: 5)),
          ),
          // Even a currently-enrolled user sees Ended, not Leave — the
          // ended check short-circuits before the enrollment status is
          // even read.
          enrolled: true,
        );
        expect(find.text('Challenge Ended'), findsOneWidget);
        expect(find.text('Leave Challenge'), findsNothing);

        // OutlinedButton.icon builds a private OutlinedButton subclass, so
        // byType(OutlinedButton) wouldn't match it — check structurally
        // via the predicate instead.
        final disabled = find.byWidgetPredicate(
          (w) => w is OutlinedButton && w.onPressed == null,
        );
        expect(disabled, findsOneWidget);
      },
    );

    testWidgets(
      'an active custom-range challenge (future end date) is not ended, shows Coming Soon',
      (tester) async {
        await _pump(
          tester,
          challenge: _challenge(
            timeWindow: ChallengeTimeWindow.customRange,
            endDate: DateTime.now().add(const Duration(days: 5)),
          ),
          enrolled: false,
        );
        expect(find.text('Coming Soon'), findsOneWidget);
        expect(find.text('Challenge Ended'), findsNothing);
      },
    );

    testWidgets('tapping Join is disabled and does not call the enrollment controller', (tester) async {
      final fake = await _pump(
        tester,
        challenge: _challenge(),
        enrolled: false,
      );
      await tester.tap(find.text('Coming Soon'));
      await tester.pump();
      expect(fake.enrollCalled, isFalse);
      expect(fake.unenrollCalled, isFalse);
    });

    testWidgets(
      'tapping Leave asks for confirmation before calling the controller',
      (tester) async {
        final fake = await _pump(
          tester,
          challenge: _challenge(),
          enrolled: true,
        );

        await tester.tap(find.text('Leave Challenge'));
        await tester.pumpAndSettle();

        // The confirm dialog is up; the controller must not have fired yet.
        expect(find.text('Leave challenge?'), findsOneWidget);
        expect(fake.unenrollCalled, isFalse);

        await tester.tap(find.text('Leave'));
        await tester.pumpAndSettle();

        expect(fake.unenrollCalled, isTrue);
      },
    );

    testWidgets('cancelling the Leave dialog does not call the controller', (
      tester,
    ) async {
      final fake = await _pump(tester, challenge: _challenge(), enrolled: true);

      await tester.tap(find.text('Leave Challenge'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(fake.unenrollCalled, isFalse);
    });
  });
}
