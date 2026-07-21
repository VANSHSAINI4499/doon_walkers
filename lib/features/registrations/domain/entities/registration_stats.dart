import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';

/// Aggregate counts backing the Profile stats section.
///
/// "Attended" is an automatic date-based approximation, not an
/// admin-marked flag — the user's explicit choice for Part D: a
/// registration counts as attended once its trek's [Registration.trekDate]
/// has passed, using the same day-level comparison as [Trek.isCompleted]
/// ([isTrekDateBefore]). This can't distinguish a genuine no-show from
/// someone who actually went, but needs no ongoing admin upkeep.
///
/// [totalRegistered] counts every registration row the user currently
/// has (self-cancelled ones are already gone — see
/// RegistrationRepository.deleteRegistration — so this can't double-count
/// a cancel-and-reregister). [cancelled] is the admin-set
/// `PaymentStatus.cancelled` subset, a different thing from a
/// self-cancellation. An unscheduled registration (no `trekDate` yet)
/// counts toward [totalRegistered] only — neither attended nor upcoming,
/// mirroring [Trek.isUpcoming]/[Trek.isCompleted]'s "unscheduled is
/// neither" rule.
class RegistrationStats {
  final int totalRegistered;
  final int totalAttended;
  final int upcoming;
  final int cancelled;

  const RegistrationStats({
    required this.totalRegistered,
    required this.totalAttended,
    required this.upcoming,
    required this.cancelled,
  });

  static const zero = RegistrationStats(
    totalRegistered: 0,
    totalAttended: 0,
    upcoming: 0,
    cancelled: 0,
  );

  factory RegistrationStats.fromRegistrations(List<Registration> registrations) {
    var attended = 0;
    var upcoming = 0;
    var cancelled = 0;
    final now = DateTime.now();

    for (final r in registrations) {
      if (r.paymentStatus == PaymentStatus.cancelled) {
        cancelled++;
        continue;
      }
      final trekDate = r.trekDate;
      if (trekDate == null) continue;
      if (isTrekDateBefore(trekDate, now)) {
        attended++;
      } else {
        upcoming++;
      }
    }

    return RegistrationStats(
      totalRegistered: registrations.length,
      totalAttended: attended,
      upcoming: upcoming,
      cancelled: cancelled,
    );
  }
}
