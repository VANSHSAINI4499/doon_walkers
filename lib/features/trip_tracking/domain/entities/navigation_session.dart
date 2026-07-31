/// Lifecycle of a [NavigationSession]. `arrived` and `cancelled` are both
/// terminal — [TripTrackingRepository.clearActiveSession] is called for
/// either; both end the session silently, with no notification or
/// summary of any kind (Trip Tracking is a background tracking engine
/// only — see TripTrackingController's doc).
enum NavigationSessionStatus { active, arrived, cancelled }

/// A single in-progress "trip" being tracked toward a destination.
///
/// Deliberately destination-agnostic — [destinationName]/[destinationLat]/
/// [destinationLng] are plain caller-supplied values, not tied to any
/// Trek-specific type. Trek Detail is the first caller (once a trek has
/// `destination_lat`/`destination_lng` set — 0046_trek_destination_
/// coordinates.sql), but nothing here references the trek_library
/// feature, so any future "navigate to X" entry point can reuse this
/// unchanged.
///
/// Exactly one of these may be [NavigationSessionStatus.active] at a
/// time — enforced by [TripTrackingController.startNavigation], not by
/// this class itself.
class NavigationSession {
  final String id;
  final String destinationName;
  final double destinationLat;
  final double destinationLng;
  final DateTime startedAt;
  final double startLat;
  final double startLng;
  final NavigationSessionStatus status;

  /// Cumulative distance travelled so far, in kilometres. Updated
  /// periodically (not on every GPS tick — see
  /// TripTrackingController's throttling) as the session progresses,
  /// so a resumed session (app restart / pragmatic reboot-resume)
  /// doesn't restart distance tracking from zero.
  final double distanceTravelledKm;

  const NavigationSession({
    required this.id,
    required this.destinationName,
    required this.destinationLat,
    required this.destinationLng,
    required this.startedAt,
    required this.startLat,
    required this.startLng,
    this.status = NavigationSessionStatus.active,
    this.distanceTravelledKm = 0,
  });

  NavigationSession copyWith({
    NavigationSessionStatus? status,
    double? distanceTravelledKm,
  }) {
    return NavigationSession(
      id: id,
      destinationName: destinationName,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
      startedAt: startedAt,
      startLat: startLat,
      startLng: startLng,
      status: status ?? this.status,
      distanceTravelledKm: distanceTravelledKm ?? this.distanceTravelledKm,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'destination_name': destinationName,
    'destination_lat': destinationLat,
    'destination_lng': destinationLng,
    'started_at': startedAt.toIso8601String(),
    'start_lat': startLat,
    'start_lng': startLng,
    'status': status.name,
    'distance_travelled_km': distanceTravelledKm,
  };

  factory NavigationSession.fromJson(Map<String, dynamic> json) {
    return NavigationSession(
      id: json['id'] as String,
      destinationName: json['destination_name'] as String,
      destinationLat: (json['destination_lat'] as num).toDouble(),
      destinationLng: (json['destination_lng'] as num).toDouble(),
      startedAt: DateTime.parse(json['started_at'] as String),
      startLat: (json['start_lat'] as num).toDouble(),
      startLng: (json['start_lng'] as num).toDouble(),
      status: NavigationSessionStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => NavigationSessionStatus.active,
      ),
      distanceTravelledKm:
          (json['distance_travelled_km'] as num?)?.toDouble() ?? 0,
    );
  }
}
