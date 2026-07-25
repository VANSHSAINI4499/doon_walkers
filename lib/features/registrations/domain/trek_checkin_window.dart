import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';

/// How long before/after the scheduled start the check-in window is
/// active — mirrors the ±3 hour window `verify_trek_checkin`
/// (0030_trek_checkin_verify.sql) enforces server-side, which itself
/// mirrors QR-1's admin Check-in QR screen
/// (trek_checkin_qr_screen.dart). Duplicated here rather than shared
/// with that screen — QR-2 doesn't touch it — so keep both in sync if
/// this window is ever retuned.
const checkinWindowHours = 3;

/// How much earlier than the real window the member-facing "Check In"
/// entry point starts appearing — purely a UX nicety (so a member
/// doesn't need to refresh at the exact minute the window opens); the
/// RPC's own window check is the real gate regardless of what this
/// returns.
const _entryPointEarlyMinutes = 30;

/// True once it's worth showing a "Check In" entry point for a trek
/// scheduled at [trekDate]/[trekStartTime], given the current time
/// [now]. False for an unscheduled trek (no date/time set at all) and
/// once the real check-in window has actually closed.
bool shouldShowCheckinEntryPoint({
  required DateTime? trekDate,
  required TrekStartTime? trekStartTime,
  required DateTime now,
}) {
  if (trekDate == null || trekStartTime == null) return false;

  final start = trekStartTime.onDate(trekDate);
  final visibleFrom = start.subtract(
    const Duration(hours: checkinWindowHours, minutes: _entryPointEarlyMinutes),
  );
  final visibleUntil = start.add(const Duration(hours: checkinWindowHours));

  return !now.isBefore(visibleFrom) && !now.isAfter(visibleUntil);
}
