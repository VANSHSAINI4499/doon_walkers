import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';
import 'package:doon_walkers/features/registrations/domain/entities/registration_stats.dart';
import 'package:flutter_test/flutter_test.dart';

Registration _registration({
  required String id,
  PaymentStatus paymentStatus = PaymentStatus.paid,
  DateTime? trekDate,
  DateTime? checkedInAt,
}) {
  return Registration(
    id: id,
    trekId: 'trek-$id',
    userId: 'user-1',
    paymentStatus: paymentStatus,
    createdAt: DateTime(2026, 1, 1),
    userName: 'Test Member',
    userEmail: 'test@example.com',
    trekTitle: 'Test Trek',
    trekDate: trekDate,
    checkedInAt: checkedInAt,
  );
}

void main() {
  group('RegistrationStats.fromRegistrations', () {
    final now = DateTime.now();
    final pastDate = now.subtract(const Duration(days: 10));
    final futureDate = now.add(const Duration(days: 10));

    test('empty list yields all zeros', () {
      final stats = RegistrationStats.fromRegistrations([]);
      expect(stats.totalRegistered, 0);
      expect(stats.totalAttended, 0);
      expect(stats.upcoming, 0);
      expect(stats.cancelled, 0);
    });

    test('a past-dated registration counts as attended', () {
      final stats = RegistrationStats.fromRegistrations([
        _registration(id: '1', trekDate: pastDate),
      ]);
      expect(stats.totalAttended, 1);
      expect(stats.upcoming, 0);
    });

    test('a future-dated registration counts as upcoming, not attended', () {
      final stats = RegistrationStats.fromRegistrations([
        _registration(id: '1', trekDate: futureDate),
      ]);
      expect(stats.totalAttended, 0);
      expect(stats.upcoming, 1);
    });

    test('a cancelled registration counts as cancelled even with a past date', () {
      final stats = RegistrationStats.fromRegistrations([
        _registration(id: '1', paymentStatus: PaymentStatus.cancelled, trekDate: pastDate),
      ]);
      expect(stats.cancelled, 1);
      expect(stats.totalAttended, 0);
      expect(stats.upcoming, 0);
    });

    test('an unscheduled registration (no trekDate) counts toward the total only', () {
      final stats = RegistrationStats.fromRegistrations([
        _registration(id: '1'),
      ]);
      expect(stats.totalRegistered, 1);
      expect(stats.totalAttended, 0);
      expect(stats.upcoming, 0);
      expect(stats.cancelled, 0);
    });

    test('totalRegistered counts every row regardless of status', () {
      final stats = RegistrationStats.fromRegistrations([
        _registration(id: '1', trekDate: pastDate),
        _registration(id: '2', trekDate: futureDate),
        _registration(id: '3', paymentStatus: PaymentStatus.cancelled, trekDate: pastDate),
        _registration(id: '4'),
      ]);
      expect(stats.totalRegistered, 4);
      expect(stats.totalAttended, 1);
      expect(stats.upcoming, 1);
      expect(stats.cancelled, 1);
    });

    test("today's date counts as upcoming, not attended (matches Trek.isUpcoming)", () {
      final stats = RegistrationStats.fromRegistrations([
        _registration(id: '1', trekDate: now),
      ]);
      expect(stats.totalAttended, 0);
      expect(stats.upcoming, 1);
    });
  });

  // Phase QR-3 — grandfathering around trekCheckinFeatureCutoff
  // (2026-07-25). Uses an injected `now` so these stay deterministic
  // regardless of when the suite actually runs, rather than depending
  // on the real clock being safely past the fixed cutoff.
  group('RegistrationStats.fromRegistrations — grandfathered attendance', () {
    final fixedNow = DateTime(2026, 8, 10);
    final postCutoffPastDate = DateTime(2026, 8, 1); // after cutoff, before fixedNow
    final preCutoffDate = DateTime(2026, 7, 1); // before cutoff, before fixedNow

    test('pre-cutoff trek: date passed is enough, checkedInAt is irrelevant', () {
      final stats = RegistrationStats.fromRegistrations(
        [_registration(id: '1', trekDate: preCutoffDate)], // no checkedInAt
        now: fixedNow,
      );
      expect(stats.totalAttended, 1);
    });

    test('post-cutoff trek with a genuine check-in counts as attended', () {
      final stats = RegistrationStats.fromRegistrations(
        [
          _registration(
            id: '1',
            trekDate: postCutoffPastDate,
            checkedInAt: postCutoffPastDate.add(const Duration(hours: 2)),
          ),
        ],
        now: fixedNow,
      );
      expect(stats.totalAttended, 1);
    });

    test('post-cutoff trek with NO check-in does NOT count as attended, '
        'even though its date passed', () {
      final stats = RegistrationStats.fromRegistrations(
        [_registration(id: '1', trekDate: postCutoffPastDate)], // no checkedInAt
        now: fixedNow,
      );
      expect(stats.totalAttended, 0);
      expect(stats.upcoming, 0); // falls into neither bucket, per the class's doc
      expect(stats.totalRegistered, 1);
    });

    test('a cancelled registration never counts as attended, even with '
        'checkedInAt set (post-cutoff)', () {
      final stats = RegistrationStats.fromRegistrations(
        [
          _registration(
            id: '1',
            paymentStatus: PaymentStatus.cancelled,
            trekDate: postCutoffPastDate,
            checkedInAt: postCutoffPastDate.add(const Duration(hours: 2)),
          ),
        ],
        now: fixedNow,
      );
      expect(stats.cancelled, 1);
      expect(stats.totalAttended, 0);
    });
  });
}
