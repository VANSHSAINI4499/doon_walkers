// Pure haversine distance/speed math — checked against a known
// reference (1 degree of latitude is ~111.19 km at any longitude) plus
// the zero-distance and zero-duration edge cases that matter for a
// same-instant reading.

import 'package:doon_walkers/features/trip_tracking/domain/services/trip_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TripGeometry.distanceMeters/distanceKm', () {
    test('same point is zero distance', () {
      final distance = TripGeometry.distanceMeters(
        startLat: 30.4167,
        startLng: 78.0537,
        endLat: 30.4167,
        endLng: 78.0537,
      );
      expect(distance, 0);
    });

    test('one degree of latitude is ~111.19 km', () {
      final km = TripGeometry.distanceKm(
        startLat: 0,
        startLng: 0,
        endLat: 1,
        endLng: 0,
      );
      expect(km, closeTo(111.19, 0.05));
    });

    test('distance is symmetric regardless of direction', () {
      final forward = TripGeometry.distanceMeters(
        startLat: 30.4,
        startLng: 78.0,
        endLat: 30.42,
        endLng: 78.06,
      );
      final reverse = TripGeometry.distanceMeters(
        startLat: 30.42,
        startLng: 78.06,
        endLat: 30.4,
        endLng: 78.0,
      );
      expect(forward, closeTo(reverse, 0.001));
    });
  });

  group('TripGeometry.averageSpeedKmh', () {
    test('computes km/h for a normal duration', () {
      final speed = TripGeometry.averageSpeedKmh(
        distanceKm: 10,
        duration: const Duration(hours: 2),
      );
      expect(speed, closeTo(5, 0.001));
    });

    test('returns null for a zero duration', () {
      final speed = TripGeometry.averageSpeedKmh(
        distanceKm: 10,
        duration: Duration.zero,
      );
      expect(speed, isNull);
    });
  });
}
