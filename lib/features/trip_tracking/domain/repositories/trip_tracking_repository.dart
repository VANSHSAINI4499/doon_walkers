import 'package:doon_walkers/features/trip_tracking/domain/entities/navigation_session.dart';

/// Local persistence for Trip Tracking state — deliberately device-local
/// (SharedPreferences-backed, see TripTrackingRepositoryImpl), not
/// synced to Supabase. This is what makes "app restart" and the
/// pragmatic reboot-resume path work: the active session survives the
/// Dart isolate being torn down, so [TripTrackingResumeProvider] can
/// pick it back up the next time the app is foregrounded.
///
/// Only ever one active session at a time — enforced by
/// [TripTrackingController], not by this interface.
///
/// Trip Tracking is a background tracking engine only — arrival ends
/// the session silently (no notification, no summary), so this
/// interface holds nothing beyond the active session itself.
abstract class TripTrackingRepository {
  Future<NavigationSession?> getActiveSession();

  Future<void> saveActiveSession(NavigationSession session);

  Future<void> clearActiveSession();
}
