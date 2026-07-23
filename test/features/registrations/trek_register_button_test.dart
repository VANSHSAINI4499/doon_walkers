// Guards the business-critical gating of TrekRegisterButton across the
// Phase 3 redesign — WHEN the CTA appears and what state shows instead
// must be identical to before. These pin the branches in
// TrekRegisterButton.build: unpublished, loading, upcoming-CTA,
// completed-closed, already-registered, and the fail-open-on-error rule.

import 'dart:async';

import 'package:doon_walkers/core/theme/app_theme.dart';
import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';
import 'package:doon_walkers/features/registrations/presentation/providers/registration_providers.dart';
import 'package:doon_walkers/features/registrations/presentation/widgets/trek_register_button.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Trek _trek({
  required bool published,
  DateTime? date,
  double fee = 0,
  String id = 't1',
}) => Trek(
  id: id,
  title: 'Roopkund',
  description: '',
  difficulty: TrekDifficulty.moderate,
  isPublished: published,
  createdAt: DateTime(2026, 1, 1),
  trekDate: date,
  registrationFee: fee,
);

Registration _registration({String? screenshotUrl}) => Registration(
  id: 'r1',
  trekId: 't1',
  userId: 'u1',
  paymentStatus: PaymentStatus.values.first,
  createdAt: DateTime(2026, 1, 1),
  userName: 'Asha',
  userEmail: 'asha@example.com',
  trekTitle: 'Roopkund',
  paymentScreenshotUrl: screenshotUrl,
);

DateTime get _tomorrow => DateTime.now().add(const Duration(days: 2));
DateTime get _yesterday => DateTime.now().subtract(const Duration(days: 2));

Future<void> _pump(
  WidgetTester tester,
  Trek trek, {
  required Override registrationOverride,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [registrationOverride],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: TrekRegisterButton(trek: trek)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('TrekRegisterButton gating (unchanged across redesign)', () {
    testWidgets('unpublished trek shows the publish-first message, no CTA', (tester) async {
      // No registration lookup happens for an unpublished trek, but supply
      // a harmless override so the family provider never hits Supabase.
      await _pump(
        tester,
        _trek(published: false, date: _tomorrow),
        registrationOverride:
            myRegistrationForTrekProvider('t1').overrideWith((ref) => Future.value(null)),
      );
      expect(find.text('Publish this trek to open registrations'), findsOneWidget);
      expect(find.text('Register for this Trek'), findsNothing);
    });

    testWidgets('while the registration lookup is loading, shows a disabled spinner', (tester) async {
      await _pump(
        tester,
        _trek(published: true, date: _tomorrow),
        registrationOverride: myRegistrationForTrekProvider('t1')
            .overrideWith((ref) => Completer<Registration?>().future),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('upcoming trek, not registered → the Register CTA', (tester) async {
      await _pump(
        tester,
        _trek(published: true, date: _tomorrow),
        registrationOverride:
            myRegistrationForTrekProvider('t1').overrideWith((ref) => Future.value(null)),
      );
      expect(find.text('Register for this Trek'), findsOneWidget);
      expect(find.textContaining('registration is closed'), findsNothing);
    });

    testWidgets('completed trek, not registered → registration closed (no CTA)', (tester) async {
      await _pump(
        tester,
        _trek(published: true, date: _yesterday),
        registrationOverride:
            myRegistrationForTrekProvider('t1').overrideWith((ref) => Future.value(null)),
      );
      expect(find.textContaining('registration is closed'), findsOneWidget);
      expect(find.text('Register for this Trek'), findsNothing);
    });

    testWidgets('already registered → the registered summary, even once completed', (tester) async {
      await _pump(
        tester,
        _trek(published: true, date: _yesterday),
        registrationOverride: myRegistrationForTrekProvider('t1')
            .overrideWith((ref) => Future.value(_registration())),
      );
      expect(find.text("You're registered"), findsOneWidget);
      expect(find.text('Register for this Trek'), findsNothing);
    });

    testWidgets('lookup error but trek still upcoming → CTA (fail open)', (tester) async {
      await _pump(
        tester,
        _trek(published: true, date: _tomorrow),
        registrationOverride:
            myRegistrationForTrekProvider('t1').overrideWith((ref) => Future.error('boom')),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Register for this Trek'), findsOneWidget);
    });

    testWidgets('lookup error and trek completed → still closed', (tester) async {
      await _pump(
        tester,
        _trek(published: true, date: _yesterday),
        registrationOverride:
            myRegistrationForTrekProvider('t1').overrideWith((ref) => Future.error('boom')),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('registration is closed'), findsOneWidget);
    });
  });
}
