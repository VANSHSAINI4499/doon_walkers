import 'dart:async';

import 'package:doon_walkers/features/trip_tracking/data/repositories/trip_tracking_repository_impl.dart';
import 'package:doon_walkers/features/trip_tracking/domain/entities/navigation_session.dart';
import 'package:doon_walkers/features/trip_tracking/domain/services/arrival_detector.dart';
import 'package:doon_walkers/features/trip_tracking/domain/services/trip_geometry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
// ServiceStatus is defined by both packages — this file only needs
// geolocator's (GPS enabled/disabled), not permission_handler's.
import 'package:permission_handler/permission_handler.dart' hide ServiceStatus;

/// Riverpod provider for [TripTrackingController].
final tripTrackingControllerProvider =
    AsyncNotifierProvider<TripTrackingController, NavigationSession?>(
      TripTrackingController.new,
      name: 'tripTrackingControllerProvider',
    );

/// Orchestrates one [NavigationSession] end to end: permission checks,
/// the adaptive-interval position stream, arrival confirmation, and the
/// single-active-session invariant. Shaped like `ActivitySyncController`
/// (activity_providers.dart) — an `AsyncNotifier` owning its own
/// subscription, exposed state doubling as "is a trip currently in
/// progress".
///
/// Purely a background tracking engine: it starts, tracks, detects
/// arrival, and silently clears the session — no notification, no
/// summary, no UI of its own. There used to be a post-arrival
/// notification/summary pipeline here; it was removed at the user's
/// request while keeping tracking/arrival-detection itself intact. Any
/// future "tell the user they've arrived" feature should be a new,
/// separate notification channel — see PushNotificationService's doc
/// for why arrival alerts must not reuse its broadcast channel.
///
/// Background-execution scope (confirmed with the user before
/// implementation): [AndroidSettings.foregroundNotificationConfig]
/// below runs Android's location updates as a genuine foreground
/// service, which is what keeps updates flowing with the screen locked
/// or the app backgrounded. It does NOT survive the app process being
/// killed or a device reboot — per geolocator_android's own
/// documentation, that would require a separate native background-
/// service package. Recovery from those cases is the deliberately
/// pragmatic path instead: [NavigationSession] is persisted after every
/// few updates, and [TripTrackingResumeProvider] resumes tracking the
/// moment the app is next opened, rather than losing the trip.
class TripTrackingController extends AsyncNotifier<NavigationSession?> {
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;
  ArrivalDetector? _arrivalDetector;
  NavigationSession? _session;
  Position? _lastPosition;
  double? _currentDistanceFilterMeters;
  int _ticksSinceLastPersist = 0;

  static const _farFilterMeters = 50.0;
  static const _midFilterMeters = 25.0;
  static const _nearFilterMeters = 10.0;
  static const _midThresholdKm = 2.0;
  static const _nearThresholdKm = 0.5;
  static const _persistEveryNTicks = 5;

  @override
  FutureOr<NavigationSession?> build() {
    ref.onDispose(_cancelSubscriptions);
    return null;
  }

  /// Starts tracking toward [destinationLat]/[destinationLng]. Tears
  /// down any existing active session first — covers both "only one
  /// navigation session may exist at a time" and "destination changed"
  /// (spec sections 1 and 9) with the same code path, rather than
  /// erroring out and making the caller cancel first.
  ///
  /// Returns false (no session created) when location permission is
  /// denied or GPS is disabled — the caller (Trek Detail) surfaces that
  /// as an inline error; returns true once tracking has actually begun.
  Future<bool> startNavigation({
    required String destinationName,
    required double destinationLat,
    required double destinationLng,
  }) async {
    await _stopTracking(persistCancelled: true);
    // Surfaced on the "Start Navigation" button (isLoading) while the
    // permission prompts and initial GPS fix below are in flight —
    // both can take a few seconds, and there's otherwise no feedback
    // that the tap registered.
    state = const AsyncLoading();

    debugPrint(
      '[TripTracking] startNavigation: requesting location permission for "$destinationName"',
    );
    final whenInUse = await Permission.locationWhenInUse.request();
    if (!whenInUse.isGranted) {
      debugPrint('[TripTracking] startNavigation: foreground location permission denied');
      state = const AsyncData(null);
      return false;
    }
    // Best-effort — a foreground service (see class doc) can keep
    // receiving updates without this on most OEMs, so denial here isn't
    // fatal, just logged. Requesting it anyway maximises compatibility
    // and satisfies Play Store background-location review requirements.
    final always = await Permission.locationAlways.request();
    debugPrint('[TripTracking] startNavigation: locationAlways=${always.name}');

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[TripTracking] startNavigation: location services disabled');
      state = const AsyncData(null);
      return false;
    }

    final Position start;
    try {
      start = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (e) {
      debugPrint('[TripTracking] startNavigation: failed to get start position: $e');
      state = const AsyncData(null);
      return false;
    }

    final session = NavigationSession(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      destinationName: destinationName,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
      startedAt: DateTime.now(),
      startLat: start.latitude,
      startLng: start.longitude,
    );

    _session = session;
    _lastPosition = start;
    _arrivalDetector = ArrivalDetector();
    await ref.read(tripTrackingRepositoryProvider).saveActiveSession(session);
    state = AsyncData(session);
    debugPrint(
      '[TripTracking] navigation started: session=${session.id} destination="$destinationName"',
    );

    _startPositionStream(_farFilterMeters);
    return true;
  }

  /// Re-attaches tracking to an already-persisted session — the
  /// pragmatic app-restart/reboot-resume path. Re-checks permission and
  /// GPS state rather than assuming they still hold, since both can
  /// change while the app wasn't running.
  Future<void> resumeSession(NavigationSession session) async {
    if (session.status != NavigationSessionStatus.active) return;

    final status = await Permission.locationWhenInUse.status;
    if (!status.isGranted) {
      debugPrint(
        '[TripTracking] resumeSession: permission no longer granted for '
        'session ${session.id}, clearing it',
      );
      await ref.read(tripTrackingRepositoryProvider).clearActiveSession();
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    _session = session;
    _arrivalDetector = ArrivalDetector();
    state = AsyncData(session);

    if (!serviceEnabled) {
      // Transient — don't clear the session over it, just wait for the
      // next resume attempt (next app open) rather than polling here.
      debugPrint(
        '[TripTracking] resumeSession: location services disabled, '
        'deferring session ${session.id}',
      );
      return;
    }

    debugPrint('[TripTracking] resumeSession: resuming session ${session.id}');
    _startPositionStream(_farFilterMeters);
  }

  /// Explicit user cancellation (spec: "Navigation cancelled").
  Future<void> cancelNavigation() async {
    await _stopTracking(persistCancelled: true);
  }

  void _startPositionStream(double distanceFilterMeters) {
    _positionSubscription?.cancel();
    _currentDistanceFilterMeters = distanceFilterMeters;

    final session = _session;
    if (session == null) return;

    final settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilterMeters.round(),
      foregroundNotificationConfig: ForegroundNotificationConfig(
        notificationTitle: 'Tracking your trip',
        notificationText: 'Navigating to ${session.destinationName}',
        notificationChannelName: 'Trip Tracking',
        setOngoing: true,
      ),
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(_onPosition, onError: _onPositionError);

    _serviceStatusSubscription ??= Geolocator.getServiceStatusStream().listen((
      status,
    ) {
      debugPrint('[TripTracking] GPS service status changed: $status');
    });
  }

  void _onPositionError(Object error, StackTrace stackTrace) {
    // Not fatal — GPS disabled, background permission revoked mid-trip,
    // etc. all surface here. The session stays persisted; resume-on-
    // launch (or the stream itself recovering, e.g. GPS re-enabled)
    // picks it back up. See class doc for the reboot/app-kill scope
    // boundary this accepts.
    debugPrint('[TripTracking] position stream error: $error');
  }

  Future<void> _onPosition(Position position) async {
    final session = _session;
    final detector = _arrivalDetector;
    if (session == null || detector == null) return;

    final previous = _lastPosition;
    final segmentKm =
        previous == null
            ? 0.0
            : TripGeometry.distanceKm(
              startLat: previous.latitude,
              startLng: previous.longitude,
              endLat: position.latitude,
              endLng: position.longitude,
            );
    _lastPosition = position;

    final updatedSession = session.copyWith(
      distanceTravelledKm: session.distanceTravelledKm + segmentKm,
    );
    _session = updatedSession;

    final remainingMeters = TripGeometry.distanceMeters(
      startLat: position.latitude,
      startLng: position.longitude,
      endLat: session.destinationLat,
      endLng: session.destinationLng,
    );
    debugPrint(
      '[TripTracking] session ${session.id}: remaining=${remainingMeters.toStringAsFixed(1)}m '
      'travelled=${updatedSession.distanceTravelledKm.toStringAsFixed(2)}km',
    );

    // Throttled persistence — not every tick, per the performance
    // requirement (avoid unnecessary writes/battery cost).
    _ticksSinceLastPersist++;
    if (_ticksSinceLastPersist >= _persistEveryNTicks) {
      _ticksSinceLastPersist = 0;
      await ref
          .read(tripTrackingRepositoryProvider)
          .saveActiveSession(updatedSession);
      state = AsyncData(updatedSession);
    }

    final remainingKm = remainingMeters / 1000;
    final desiredFilter =
        remainingKm <= _nearThresholdKm
            ? _nearFilterMeters
            : remainingKm <= _midThresholdKm
            ? _midFilterMeters
            : _farFilterMeters;
    if (desiredFilter != _currentDistanceFilterMeters) {
      debugPrint(
        '[TripTracking] adaptive interval: switching distanceFilter to '
        '${desiredFilter}m at ${remainingKm.toStringAsFixed(2)}km remaining',
      );
      _startPositionStream(desiredFilter);
    }

    if (detector.recordReading(remainingMeters)) {
      debugPrint('[TripTracking] arrival detected for session ${session.id}');
      await _handleArrival(updatedSession);
    }
  }

  /// Arrival is silent by design (see class doc) — cancel the position
  /// stream (the single guard against acting on this twice for the
  /// same session, since a fast subsequent GPS tick could otherwise
  /// land mid-teardown) and clear the session. No notification, no
  /// summary, nothing shown to the user.
  Future<void> _handleArrival(NavigationSession session) async {
    await _cancelSubscriptions();
    await ref.read(tripTrackingRepositoryProvider).clearActiveSession();

    _session = null;
    _arrivalDetector = null;
    _lastPosition = null;
    state = const AsyncData(null);

    debugPrint(
      '[TripTracking] session ${session.id} ended: arrived at "${session.destinationName}"',
    );
  }

  Future<void> _stopTracking({required bool persistCancelled}) async {
    final session = _session;
    await _cancelSubscriptions();
    _session = null;
    _arrivalDetector = null;
    _lastPosition = null;

    if (session != null) {
      debugPrint('[TripTracking] stopping session ${session.id} (cancelled=$persistCancelled)');
      if (persistCancelled) {
        await ref.read(tripTrackingRepositoryProvider).clearActiveSession();
      }
    }
    state = const AsyncData(null);
  }

  Future<void> _cancelSubscriptions() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    await _serviceStatusSubscription?.cancel();
    _serviceStatusSubscription = null;
  }
}

/// Fire-and-forget resume-on-launch — watched once from
/// [DoonWalkersApp], same pattern as `activityLaunchSyncProvider`/
/// `pushTokenSyncProvider` (main.dart). Checks for a persisted active
/// session at startup and resumes tracking if one exists; this is the
/// "app restart"/"app killed"/pragmatic-reboot-resume path (see
/// [TripTrackingController]'s doc for the scope boundary).
final tripTrackingResumeProvider = Provider<void>((ref) {
  Future(() async {
    final session =
        await ref.read(tripTrackingRepositoryProvider).getActiveSession();
    if (session == null) return;
    debugPrint(
      '[TripTracking] resume-on-launch: found persisted session ${session.id}',
    );
    await ref.read(tripTrackingControllerProvider.notifier).resumeSession(session);
  });
}, name: 'tripTrackingResumeProvider');
