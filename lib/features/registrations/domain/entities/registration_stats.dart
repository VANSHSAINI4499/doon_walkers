import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';

/// The calendar date the check-in QR feature went live (Phase QR-2's
/// `trek_checkin_verify` migration, applied 2026-07-25) — the earliest
/// possible date [Registration.checkedInAt] could ever be non-null.
///
/// MUST match `public.trek_checkin_feature_cutoff()`
/// (0031_trek_attendance_grandfather.sql) exactly — the two can't be
/// kept in sync automatically since they live in separate deployables;
/// if this ever needs to change, change both.
final trekCheckinFeatureCutoff = DateTime(2026, 7, 25);

/// Aggregate counts backing the Profile stats section.
///
/// "Attended" is grandfathered (Phase QR-3, mirrors
/// `public.trek_registration_is_attended()` exactly — see
/// 0031_trek_attendance_grandfather.sql):
///   - For a trek dated before [trekCheckinFeatureCutoff]: the original
///     date-based approximation — registered, [Registration.trekDate]
///     has passed, not cancelled. These treks predate check-in and can
///     never have a real record to reference.
///   - For a trek dated on/after the cutoff: [Registration.checkedInAt]
///     IS NOT NULL, full stop — a registration for a past trek with no
///     scan does NOT count, even though it would have under the old rule.
/// A cancelled registration never counts as attended either way.
///
/// [totalRegistered] counts every registration row the user currently
/// has (self-cancelled ones are already gone — see
/// RegistrationRepository.deleteRegistration — so this can't double-count
/// a cancel-and-reregister). [cancelled] is the admin-set
/// `PaymentStatus.cancelled` subset, a different thing from a
/// self-cancellation. An unscheduled registration (no `trekDate` yet)
/// counts toward [totalRegistered] only — neither attended nor upcoming,
/// mirroring [Trek.isUpcoming]/[Trek.isCompleted]'s "unscheduled is
/// neither" rule. A POST-cutoff trek whose date has passed with no
/// check-in gets the same "neither" treatment — it's not upcoming (the
/// date passed) and, unlike before QR-3, no longer counts as attended
/// either.
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

  /// [now] defaults to the real clock — overridable so tests can pin a
  /// deterministic "today" without depending on when they happen to run
  /// relative to [trekCheckinFeatureCutoff] (a fixed calendar date).
  factory RegistrationStats.fromRegistrations(
    List<Registration> registrations, {
    DateTime? now,
  }) {
    var attended = 0;
    var upcoming = 0;
    var cancelled = 0;
    final effectiveNow = now ?? DateTime.now();

    for (final r in registrations) {
      if (r.paymentStatus == PaymentStatus.cancelled) {
        cancelled++;
        continue;
      }
      final trekDate = r.trekDate;
      if (trekDate == null) continue;

      if (!isTrekDateBefore(trekDate, effectiveNow)) {
        upcoming++;
        continue;
      }

      // Trek's date has passed — which side of the cutoff decides how
      // "attended" is determined (Phase QR-3).
      if (isTrekDateBefore(trekDate, trekCheckinFeatureCutoff)) {
        attended++; // pre-cutoff: old approximation — no check-in record could ever exist
      } else if (r.checkedInAt != null) {
        attended++; // post-cutoff: only a genuine scan counts
      }
      // else: date passed, post-cutoff, never checked in — counts
      // toward totalRegistered only, same treatment as an unscheduled
      // registration above.
    }

    return RegistrationStats(
      totalRegistered: registrations.length,
      totalAttended: attended,
      upcoming: upcoming,
      cancelled: cancelled,
    );
  }
}
