// Widget coverage for Phase 15's Upcoming/Completed/Cancelled tabs on "My
// Registrations". registration_status_group_test.dart already pins the
// pure classification rule; these tests pin that the SCREEN actually
// applies it — tab switching shows/hides the right rows, the milestone
// banner appears only on Completed, and it stays combined correctly with
// the pre-existing search filter.

import 'package:doon_walkers/core/theme/app_theme.dart';
import 'package:doon_walkers/features/registrations/data/repositories/registration_repository_impl.dart';
import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';
import 'package:doon_walkers/features/registrations/domain/repositories/registration_repository.dart';
import 'package:doon_walkers/features/registrations/presentation/screens/my_registrations_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal in-memory [RegistrationRepository] — just enough for
/// MyRegistrationsScreen's own two dependencies (the paginated fetch and
/// the full-list fetch `myRegistrationStatsProvider` sits on top of),
/// everything else throws to make an accidental extra call obvious.
class _FakeRegistrationRepository implements RegistrationRepository {
  _FakeRegistrationRepository(this.registrations);

  final List<Registration> registrations;

  @override
  Future<List<Registration>> fetchMyRegistrations({int? limit}) async =>
      limit == null ? registrations : registrations.take(limit).toList();

  @override
  Future<List<Registration>> fetchMyRegistrationsPage({
    required int page,
    required int pageSize,
  }) async {
    final start = page * pageSize;
    if (start >= registrations.length) return const [];
    final end = (start + pageSize).clamp(0, registrations.length);
    return registrations.sublist(start, end);
  }

  @override
  Never noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not faked for this test');
}

Registration _registration({
  required String id,
  required String title,
  PaymentStatus paymentStatus = PaymentStatus.paid,
  DateTime? trekDate,
  DateTime? checkedInAt,
}) => Registration(
  id: id,
  trekId: 'trek-$id',
  userId: 'u1',
  paymentStatus: paymentStatus,
  createdAt: DateTime(2026, 1, 1),
  userName: 'Asha',
  userEmail: 'asha@example.com',
  trekTitle: title,
  trekDate: trekDate,
  checkedInAt: checkedInAt,
  // A screenshot url is what makes `involvedPayment` true — irrelevant to
  // grouping, kept null so the status chip doesn't add noise to text
  // finders in these tests.
);

final _future = DateTime(2026, 8, 20);
final _past = DateTime(2026, 6, 1);

Future<void> _pumpScreen(WidgetTester tester, List<Registration> registrations) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        registrationRepositoryProvider.overrideWithValue(
          _FakeRegistrationRepository(registrations),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const MyRegistrationsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('MyRegistrationsScreen tabs (Phase 15)', () {
    final fixtures = [
      _registration(id: '1', title: 'Kedarkantha', trekDate: _future),
      _registration(id: '2', title: 'Roopkund', trekDate: _past, checkedInAt: _past),
      _registration(
        id: '3',
        title: 'Valley of Flowers',
        paymentStatus: PaymentStatus.cancelled,
        trekDate: _future,
      ),
    ];

    testWidgets('defaults to the Upcoming tab', (tester) async {
      await _pumpScreen(tester, fixtures);
      expect(find.text('Kedarkantha'), findsOneWidget);
      expect(find.text('Roopkund'), findsNothing);
      expect(find.text('Valley of Flowers'), findsNothing);
    });

    testWidgets('Completed tab shows only the past, non-cancelled trek', (tester) async {
      await _pumpScreen(tester, fixtures);
      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();

      expect(find.text('Roopkund'), findsOneWidget);
      expect(find.text('Kedarkantha'), findsNothing);
      expect(find.text('Valley of Flowers'), findsNothing);
    });

    testWidgets('Cancelled tab shows only the cancelled registration', (tester) async {
      await _pumpScreen(tester, fixtures);
      await tester.tap(find.text('Cancelled'));
      await tester.pumpAndSettle();

      expect(find.text('Valley of Flowers'), findsOneWidget);
      expect(find.text('Kedarkantha'), findsNothing);
      expect(find.text('Roopkund'), findsNothing);
    });

    testWidgets('the milestone banner appears only on the Completed tab', (tester) async {
      await _pumpScreen(tester, fixtures);
      expect(find.textContaining("You've completed"), findsNothing);

      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();
      // One verified-attended registration (Roopkund: past date + checked
      // in) in the fixture set.
      expect(find.text("You've completed 1 trek"), findsOneWidget);

      await tester.tap(find.text('Cancelled'));
      await tester.pumpAndSettle();
      expect(find.textContaining("You've completed"), findsNothing);
    });

    testWidgets('an empty tab shows tab-specific copy, not the generic empty state', (
      tester,
    ) async {
      // No cancelled registrations in this fixture set.
      await _pumpScreen(tester, [
        _registration(id: '1', title: 'Kedarkantha', trekDate: _future),
      ]);
      await tester.tap(find.text('Cancelled'));
      await tester.pumpAndSettle();
      expect(find.text('No cancelled registrations.'), findsOneWidget);
    });

    testWidgets('search and tab combine — a search match outside the tab is hidden', (
      tester,
    ) async {
      await _pumpScreen(tester, fixtures);
      // Still on Upcoming (default). Searching for the cancelled trek's
      // title must show nothing, not fall back to matching another tab.
      await tester.enterText(find.byType(TextField), 'Valley');
      await tester.pumpAndSettle();
      expect(find.text('Valley of Flowers'), findsNothing);
    });

    testWidgets('renders in light theme without throwing', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            registrationRepositoryProvider.overrideWithValue(
              _FakeRegistrationRepository(fixtures),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const MyRegistrationsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
