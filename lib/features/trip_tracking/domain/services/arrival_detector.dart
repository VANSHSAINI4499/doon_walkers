/// Consecutive-confirmation arrival state machine — spec: "Avoid false
/// positives by confirming arrival for multiple consecutive location
/// updates" rather than declaring arrival off a single (possibly noisy)
/// GPS fix.
///
/// Pure and stateful but plugin-free: [TripTrackingController] feeds it
/// one distance reading at a time as they arrive from the position
/// stream; it has no knowledge of geolocator, Health Connect, or
/// notifications, which is what makes it directly unit-testable (see
/// test/features/trip_tracking/arrival_detector_test.dart).
class ArrivalDetector {
  ArrivalDetector({this.thresholdMeters = 50, this.requiredConfirmations = 3})
    : assert(thresholdMeters > 0),
      assert(requiredConfirmations >= 1);

  /// Spec default: 50 meters.
  final double thresholdMeters;

  /// How many consecutive within-threshold readings are needed before
  /// [recordReading] reports arrival. Spec default: 3.
  final int requiredConfirmations;

  int _consecutiveWithinThreshold = 0;

  /// Feeds one new distance-to-destination reading (in meters).
  /// Returns true once [requiredConfirmations] consecutive readings
  /// have all been within [thresholdMeters]. A reading that falls back
  /// outside the threshold resets the count, so GPS jitter near the
  /// boundary can't trigger a false positive. Callers should stop
  /// feeding further readings as soon as this returns true (see
  /// TripTrackingController, which cancels the position stream on the
  /// first true) — it keeps returning true on every call after that
  /// point, it isn't itself a one-shot latch.
  bool recordReading(double distanceMeters) {
    if (distanceMeters <= thresholdMeters) {
      _consecutiveWithinThreshold++;
    } else {
      _consecutiveWithinThreshold = 0;
    }
    return _consecutiveWithinThreshold >= requiredConfirmations;
  }

  void reset() => _consecutiveWithinThreshold = 0;
}
