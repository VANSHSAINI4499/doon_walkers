// The Upcoming/Completed/Cancelled split on "My Registrations" (Phase 15).
// Every rule here mirrors RegistrationStats.fromRegistrations exactly, so
// these tests pin agreement with the Profile stats card as much as they
// pin the grouping itself — a registration must never read "Completed"
// here while counting as "upcoming" in the stats total, or vice versa.

import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';
import 'package:doon_walkers/features/registrations/domain/services/registration_status_group.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 7, 26);

Registration _registration({
  PaymentStatus paymentStatus = PaymentStatus.paid,
  DateTime? trekDate,
  DateTime? checkedInAt,
}) => Registration(
  id: 'r1',
  trekId: 't1',
  userId: 'u1',
  paymentStatus: paymentStatus,
  createdAt: DateTime(2026, 1, 1),
  userName: 'Asha',
  userEmail: 'asha@example.com',
  trekTitle: 'Nag Tibba',
  trekDate: trekDate,
  checkedInAt: checkedInAt,
);

RegistrationStatusGroup _groupOf(Registration r) =>
    registrationStatusGroupFor(r, now: _now);

void main() {
  group('registrationStatusGroupFor', () {
    test('a future trek date is Upcoming', () {
      expect(
        _groupOf(_registration(trekDate: DateTime(2026, 8, 1))),
        RegistrationStatusGroup.upcoming,
      );
    });

    test("today's trek date is Upcoming, not Completed", () {
      // Matches Trek.isUpcoming's own day-granular rule: today counts as
      // upcoming, the day isn't over yet.
      expect(
        _groupOf(_registration(trekDate: _now)),
        RegistrationStatusGroup.upcoming,
      );
    });

    test('a past trek date is Completed', () {
      expect(
        _groupOf(_registration(trekDate: DateTime(2026, 7, 1))),
        RegistrationStatusGroup.completed,
      );
    });

    test('a past date is Completed whether or not check-in was verified', () {
      // The tab split does not encode checkedInAt at all — see the
      // function's own doc for why that distinction belongs to the tile,
      // not a fourth tab.
      expect(
        _groupOf(
          _registration(
            trekDate: DateTime(2026, 7, 1),
            checkedInAt: DateTime(2026, 7, 1, 9),
          ),
        ),
        RegistrationStatusGroup.completed,
      );
      expect(
        _groupOf(
          _registration(trekDate: DateTime(2026, 7, 1), checkedInAt: null),
        ),
        RegistrationStatusGroup.completed,
      );
    });

    test('cancelled takes precedence over a future date', () {
      // The real scenario this guards: an admin refunds and cancels a
      // registration for a trek that hasn't happened yet. It must read
      // Cancelled, not Upcoming.
      expect(
        _groupOf(
          _registration(
            paymentStatus: PaymentStatus.cancelled,
            trekDate: DateTime(2026, 8, 1),
          ),
        ),
        RegistrationStatusGroup.cancelled,
      );
    });

    test('cancelled takes precedence over a past date too', () {
      expect(
        _groupOf(
          _registration(
            paymentStatus: PaymentStatus.cancelled,
            trekDate: DateTime(2026, 7, 1),
          ),
        ),
        RegistrationStatusGroup.cancelled,
      );
    });

    test('cancelled takes precedence over no date at all', () {
      expect(
        _groupOf(_registration(paymentStatus: PaymentStatus.cancelled)),
        RegistrationStatusGroup.cancelled,
      );
    });

    test('every other payment status is unaffected by this split', () {
      // Only `cancelled` short-circuits to the Cancelled bucket — pending
      // and refunded registrations for an upcoming trek must still read
      // as Upcoming, since payment state and trek timing are independent
      // questions for anything other than cancellation.
      for (final status in [
        PaymentStatus.pending,
        PaymentStatus.paid,
        PaymentStatus.refunded,
      ]) {
        expect(
          _groupOf(
            _registration(
              paymentStatus: status,
              trekDate: DateTime(2026, 8, 1),
            ),
          ),
          RegistrationStatusGroup.upcoming,
          reason: '$status must not be treated as cancelled',
        );
      }
    });

    test('an unscheduled registration (no trekDate) is Upcoming', () {
      // A legacy row from before trek scheduling existed — neither
      // strictly upcoming nor completed, bucketed as the least-wrong of
      // the three real tabs. See the function's own doc.
      expect(_groupOf(_registration()), RegistrationStatusGroup.upcoming);
    });

    test('label text matches the three real tabs', () {
      expect(RegistrationStatusGroup.upcoming.label, 'Upcoming');
      expect(RegistrationStatusGroup.completed.label, 'Completed');
      expect(RegistrationStatusGroup.cancelled.label, 'Cancelled');
    });
  });
}
