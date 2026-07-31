import 'dart:math' as math;

/// Pure straight-line geometry for Trip Tracking — no plugin/IO
/// dependency, so it's unit-testable without a device or emulator (see
/// test/features/trip_tracking/trip_geometry_test.dart).
///
/// Deliberately not sourced from the `geolocator` package's own
/// `Geolocator.distanceBetween` — that call requires the platform
/// implementation to be initialised, which isn't available in plain
/// `flutter test`. A local haversine implementation keeps the arrival-
/// distance math testable in isolation from geolocator entirely.
class TripGeometry {
  const TripGeometry._();

  static const _earthRadiusMeters = 6371000.0;

  /// Great-circle distance between two points, in meters. Accurate
  /// enough for arrival-threshold checks (tens of meters) at the trek
  /// distances this app deals with — no need for a more precise
  /// ellipsoidal (Vincenty) calculation.
  static double distanceMeters({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    final dLat = _toRadians(endLat - startLat);
    final dLng = _toRadians(endLng - startLng);
    final lat1 = _toRadians(startLat);
    final lat2 = _toRadians(endLat);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLng / 2) * math.sin(dLng / 2) * math.cos(lat1) * math.cos(lat2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusMeters * c;
  }

  static double distanceKm({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) =>
      distanceMeters(
        startLat: startLat,
        startLng: startLng,
        endLat: endLat,
        endLng: endLng,
      ) /
      1000;

  /// km/h, or null for a zero/negative duration (a same-instant
  /// reading — avoids a divide-by-zero rather than returning infinity).
  static double? averageSpeedKmh({
    required double distanceKm,
    required Duration duration,
  }) {
    final hours = duration.inSeconds / 3600;
    if (hours <= 0) return null;
    return distanceKm / hours;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;
}
