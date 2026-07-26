import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';

/// Which of the three "My Registrations" tabs a registration belongs in —
/// Redesign 2.0, Phase 15.
///
/// Deliberately three groups, matching the reference exactly, built ONLY
/// from real columns: [Registration.paymentStatus] and
/// [Registration.trekDate] (both already joined and populated — see
/// `RegistrationRepositoryImpl`'s `treks(title, trek_date)` join). No new
/// data, no new query.
enum RegistrationStatusGroup {
  upcoming,
  completed,
  cancelled;

  String get label => switch (this) {
    RegistrationStatusGroup.upcoming => 'Upcoming',
    RegistrationStatusGroup.completed => 'Completed',
    RegistrationStatusGroup.cancelled => 'Cancelled',
  };
}

/// Classifies [registration] into one of the three groups.
///
/// The precedence and the date rule are not new inventions — both mirror
/// [RegistrationStats.fromRegistrations] exactly, so a registration can
/// never disagree between the Profile stats card and this tab split:
///
///  1. **Cancelled takes precedence over date.** An admin can set
///     `payment_status = cancelled` on a registration for a still-upcoming
///     trek (most often after a refund) — that registration is Cancelled,
///     not Upcoming, regardless of the date. Note a MEMBER'S OWN
///     self-cancellation never reaches this function at all: cancelling
///     your own registration deletes the row
///     ([RegistrationRepository.deleteRegistration]), so "Cancelled" here
///     only ever means an admin-set status the member is still allowed to
///     see, per `registrations_select`'s own-row policy.
///  2. **Date decides Upcoming vs. Completed**, using [isTrekDateBefore] —
///     the same day-granular comparison [Trek.isUpcoming]/[Trek.isCompleted]
///     and the sort in `sortTreksForLibrary` already use, so this tab
///     split can't disagree with how the Trek Library groups the same
///     trek.
///  3. **An unscheduled registration** (no [Registration.trekDate] at
///     all — a legacy row from before trek scheduling existed) is bucketed
///     as Upcoming. Neither "upcoming" nor "completed" is strictly true
///     for it (see [Trek.isUpcoming]/[Trek.isCompleted]'s own "neither"
///     case, and [RegistrationStats]' "counts toward totalRegistered
///     only" treatment) — but every registration must land in exactly one
///     of the three real tabs, and "not cancelled, hasn't happened" is the
///     least-wrong reading of the three.
///
/// ## What this deliberately does NOT encode
///
/// Whether the member was actually **verified checked in**
/// ([Registration.checkedInAt]) plays no part in this split — a past-dated,
/// non-cancelled registration is "Completed" whether or not a scan was
/// ever recorded (this can happen for a post-QR-cutoff trek whose date
/// passed with no check-in). That distinction is real and worth showing,
/// just not as a fourth tab — the Completed tab's own tile shows a
/// "Checked in" mark when [Registration.checkedInAt] is set, same signal
/// [TrekRegisterButton] already uses.
RegistrationStatusGroup registrationStatusGroupFor(
  Registration registration, {
  DateTime? now,
}) {
  if (registration.paymentStatus == PaymentStatus.cancelled) {
    return RegistrationStatusGroup.cancelled;
  }

  final trekDate = registration.trekDate;
  if (trekDate == null) return RegistrationStatusGroup.upcoming;

  return isTrekDateBefore(trekDate, now ?? DateTime.now())
      ? RegistrationStatusGroup.completed
      : RegistrationStatusGroup.upcoming;
}
