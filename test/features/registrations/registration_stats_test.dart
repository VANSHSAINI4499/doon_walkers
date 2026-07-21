import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';
import 'package:doon_walkers/features/registrations/domain/entities/registration_stats.dart';
import 'package:flutter_test/flutter_test.dart';

Registration _registration({
  required String id,
  PaymentStatus paymentStatus = PaymentStatus.paid,
  DateTime? trekDate,
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
}
