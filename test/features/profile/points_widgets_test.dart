// Points summary card + Points History screen against a fake
// PointsRepository (no live Supabase). Covers: real figures render (no
// invented data), the reason-label mapping shows human copy on screen
// (never a raw enum), day-grouping renders in the actual screen, the
// empty state, and both themes.

import 'package:doon_walkers/core/theme/app_theme.dart';
import 'package:doon_walkers/features/profile/data/repositories/points_repository_impl.dart';
import 'package:doon_walkers/features/profile/domain/entities/points_ledger_entry.dart';
import 'package:doon_walkers/features/profile/domain/entities/points_summary.dart';
import 'package:doon_walkers/features/profile/domain/repositories/points_repository.dart';
import 'package:doon_walkers/features/profile/presentation/screens/points_history_screen.dart';
import 'package:doon_walkers/features/profile/presentation/widgets/points_summary_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePointsRepository implements PointsRepository {
  _FakePointsRepository({required this.summary, this.entries = const []});

  final PointsSummary summary;
  final List<PointsLedgerEntry> entries;

  @override
  Future<PointsSummary> fetchMySummary() async => summary;

  @override
  Future<List<PointsLedgerEntry>> fetchMyHistoryPage({
    required int page,
    required int pageSize,
  }) async {
    final from = page * pageSize;
    if (from >= entries.length) return const [];
    final to = (from + pageSize).clamp(0, entries.length);
    return entries.sublist(from, to);
  }
}

/// [PointsSummarySection]'s "View History" link calls `context.push` only
/// inside its `onTap`, never during build, so a plain (non-GoRouter)
/// `MaterialApp` is enough here — none of these tests tap it.
Widget _plainHost(
  Widget child, {
  required PointsRepository repository,
  ThemeData? theme,
}) => ProviderScope(
  overrides: [pointsRepositoryProvider.overrideWithValue(repository)],
  child: MaterialApp(
    theme: theme ?? AppTheme.dark,
    home: Scaffold(body: child),
  ),
);

void main() {
  group('PointsSummarySection', () {
    testWidgets('shows real total points, level badge, and progress label', (
      tester,
    ) async {
      const summary = PointsSummary(
        totalPoints: 1000,
        level: 2,
        currentLevelFloor: 500,
        nextLevel: 3,
        pointsToNextLevel: 500,
        isMaxLevel: false,
      );
      await tester.pumpWidget(
        _plainHost(
          const PointsSummarySection(),
          repository: _FakePointsRepository(summary: summary),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1000'), findsOneWidget);
      expect(find.text('Lv. 2'), findsOneWidget);
      expect(find.text('Progress to Level 3'), findsOneWidget);
      expect(find.text('500 to go'), findsOneWidget);
      expect(find.text('View History'), findsOneWidget);
    });

    testWidgets(
      'a max-level member sees "Top level reached", not a broken next-level line',
      (tester) async {
        const summary = PointsSummary(
          totalPoints: 20000,
          level: 8,
          currentLevelFloor: 15000,
          nextLevel: null,
          pointsToNextLevel: null,
          isMaxLevel: true,
        );
        await tester.pumpWidget(
          _plainHost(
            const PointsSummarySection(),
            repository: _FakePointsRepository(summary: summary),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Top level reached'), findsOneWidget);
        expect(find.text('Lv. 8'), findsOneWidget);
      },
    );

    testWidgets('renders in light theme too, no exceptions', (tester) async {
      const summary = PointsSummary(
        totalPoints: 0,
        level: 1,
        currentLevelFloor: 0,
        nextLevel: 2,
        pointsToNextLevel: 500,
        isMaxLevel: false,
      );
      await tester.pumpWidget(
        _plainHost(
          const PointsSummarySection(),
          repository: _FakePointsRepository(summary: summary),
          theme: AppTheme.light,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('PointsHistoryScreen', () {
    testWidgets(
      'empty ledger shows the honest empty state, not a spinner or crash',
      (tester) async {
        await tester.pumpWidget(
          _plainHost(
            const PointsHistoryScreen(),
            repository: _FakePointsRepository(summary: PointsSummary.guest),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining("haven't earned any points yet"),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'renders real entries grouped by day with human reason labels',
      (tester) async {
        final now = DateTime.now();
        final entries = [
          PointsLedgerEntry(
            id: '1',
            points: 25,
            reason: 'daily_step_goal',
            referenceId: null,
            createdAt: now,
          ),
          PointsLedgerEntry(
            id: '2',
            points: 10,
            reason: 'challenge_enrolled',
            referenceId: 'c1',
            createdAt: now.subtract(const Duration(days: 5)),
          ),
          PointsLedgerEntry(
            id: '3',
            points: 5,
            reason: 'some_future_reason',
            referenceId: null,
            createdAt: now.subtract(const Duration(days: 5)),
          ),
        ];

        await tester.pumpWidget(
          _plainHost(
            const PointsHistoryScreen(),
            repository: _FakePointsRepository(
              summary: PointsSummary.guest,
              entries: entries,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Real, mapped labels — never the raw reason strings.
        expect(find.text('Hit your daily step goal'), findsOneWidget);
        expect(find.text('Joined a challenge'), findsOneWidget);
        expect(find.text('daily_step_goal'), findsNothing);
        expect(find.text('challenge_enrolled'), findsNothing);
        expect(find.text('some_future_reason'), findsNothing);
        // Unmapped reason falls back to the generic label.
        expect(find.text('Points update'), findsOneWidget);

        // Signed amounts render with an explicit "+".
        expect(find.text('+25'), findsOneWidget);
        expect(find.text('+10'), findsOneWidget);

        // Day headings.
        expect(find.text('TODAY'), findsOneWidget);
      },
    );
  });
}
