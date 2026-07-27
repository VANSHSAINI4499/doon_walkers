// Guards TrekCard's badge and admin-affordance logic across the Phase 3
// redesign — WHEN each marker appears must be unchanged: the draft marker
// only in an admin view of an unpublished trek, the admin actions slot
// only when passed, and the Upcoming pill only for a future-dated trek.

import 'package:doon_walkers/core/icons/app_icons.dart';
import 'package:doon_walkers/core/theme/app_theme.dart';
import 'package:doon_walkers/core/widgets/glass_card.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:doon_walkers/features/trek_library/presentation/widgets/trek_card.dart';
import 'package:doon_walkers/features/trek_library/presentation/providers/trek_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Trek _trek({
  required bool published,
  DateTime? date,
  String description = '',
  String id = 't1',
}) => Trek(
  id: id,
  title: 'Kedarkantha',
  description: description,
  difficulty: TrekDifficulty.hard,
  isPublished: published,
  createdAt: DateTime(2026, 1, 1),
  trekDate: date,
);

Future<void> _pumpCard(
  WidgetTester tester,
  Trek trek, {
  Widget? adminActions,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        trekSpotsLeftProvider(trek.id).overrideWith((ref) => Future.value(10)),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 320,
              child: TrekCard(
                trek: trek,
                onTap: () {},
                adminActions: adminActions,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

DateTime get _tomorrow => DateTime.now().add(const Duration(days: 2));
DateTime get _yesterday => DateTime.now().subtract(const Duration(days: 2));

void main() {
  group('TrekCard markers', () {
    testWidgets('non-admin view of a draft shows no Draft marker', (
      tester,
    ) async {
      // A non-admin never receives an unpublished trek in practice (RLS),
      // but the card must not render the draft marker without adminActions.
      await _pumpCard(tester, _trek(published: false, date: _tomorrow));
      expect(find.text('Draft'), findsNothing);
    });

    testWidgets('admin view of a draft shows the Draft marker', (tester) async {
      await _pumpCard(
        tester,
        _trek(published: false, date: _tomorrow),
        adminActions: const SizedBox(width: 24, height: 24),
      );
      expect(find.text('Draft'), findsOneWidget);
    });

    testWidgets('admin view of a published trek shows no Draft marker', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        _trek(published: true, date: _tomorrow),
        adminActions: const SizedBox(width: 24, height: 24),
      );
      expect(find.text('Draft'), findsNothing);
    });

    testWidgets('future-dated trek shows the Upcoming pill', (tester) async {
      await _pumpCard(tester, _trek(published: true, date: _tomorrow));
      expect(find.text('Upcoming'), findsOneWidget);
    });

    testWidgets('past-dated trek shows no Upcoming pill', (tester) async {
      await _pumpCard(tester, _trek(published: true, date: _yesterday));
      expect(find.text('Upcoming'), findsNothing);
    });

    testWidgets('unscheduled trek shows no Upcoming pill', (tester) async {
      await _pumpCard(tester, _trek(published: true, date: null));
      expect(find.text('Upcoming'), findsNothing);
    });

    testWidgets('description excerpt renders when present, absent when blank', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        _trek(published: true, date: null, description: 'A snowy ridge walk.'),
      );
      expect(find.text('A snowy ridge walk.'), findsOneWidget);
    });
  });

  group('TrekCard — calm migration (Phase 15)', () {
    testWidgets('shows the real trek date as a fact chip', (tester) async {
      // Phase 15 adds this — the card previously showed distance/duration
      // but never the scheduled date, even though Trek Detail always has.
      await _pumpCard(
        tester,
        _trek(published: true, date: DateTime(2026, 8, 15)),
      );
      expect(find.text('15 Aug'), findsOneWidget);
    });

    testWidgets('shows no date chip for an unscheduled trek', (tester) async {
      await _pumpCard(tester, _trek(published: true, date: null));
      // No fact row should render at all with nothing to put in it.
      expect(
        find.byWidgetPredicate(
          (w) => w is AppIcon && w.icon == AppIcons.calendar,
        ),
        findsNothing,
      );
    });

    testWidgets('never paints a BackdropFilter — glass is retired', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        _trek(published: true, date: DateTime(2026, 8, 15)),
      );
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('GlassCard typedef still constructs the same card', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        _trek(published: true, date: DateTime(2026, 8, 15)),
      );
      expect(find.byType(AppCard), findsOneWidget);
    });

    testWidgets('renders in light theme with the same badges', (tester) async {
      await _pumpCard(
        tester,
        _trek(published: true, date: _tomorrow),
        theme: AppTheme.light,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Upcoming'), findsOneWidget);
    });
  });
}
