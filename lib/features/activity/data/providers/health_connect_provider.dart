import 'package:doon_walkers/features/activity/domain/entities/daily_activity.dart';
import 'package:doon_walkers/features/activity/domain/repositories/activity_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

/// First (and currently only) real [ActivityProvider] implementation —
/// reads steps/distance/calories from Android Health Connect via the
/// `health` package. Read-only: this app never writes health data.
///
/// [_types]/[_permissions] request READ access to exactly three data
/// types — nothing else — matching the explanation shown to the user
/// before requesting (see ActivityPermissionBanner).
///
/// ### Why steps used to come out roughly double Google Fit's number
///
/// Health Connect is a shared platform datastore: more than one
/// installed app can write `StepsRecord`s into it independently (most
/// commonly Google Fit *and* the phone manufacturer's own health app —
/// Samsung Health, Xiaomi/Mi Fitness, etc. — once both are granted
/// write access). [readDailyActivity] used to read steps with
/// `Health.getTotalStepsInInterval`, which (see the `health` package's
/// Android implementation, `HealthDataReader.getAggregatedStepCount`)
/// calls Health Connect's own `AggregateRequest(StepsRecord.COUNT_TOTAL)`
/// with no `dataOriginFilter`. That aggregate is real and correct for
/// what it does — it just sums the `COUNT_TOTAL` metric across *every*
/// contributing app in range. Health Connect has no way to know that
/// two apps' step counts for the same walk represent the same physical
/// steps, so a device with two step-tracking sources hooked up reports
/// roughly the sum of both — the classic "almost double" symptom,
/// because Google Fit alone only shows its own count.
///
/// This was never a bug in *our* code manually summing raw records —
/// quite the opposite: we were correctly using the platform's own
/// recommended aggregate call. The bug is that the aggregate's
/// contract (sum every origin, no cross-app dedup) doesn't match what
/// a step count displayed to a user should mean when multiple sources
/// exist. [readDailyActivity] now reads raw `StepsRecord`s first to see
/// how many distinct data origins (`HealthDataPoint.sourceName`, which
/// is Health Connect's `Metadata.dataOrigin.packageName`) actually
/// contributed that day:
///  - Exactly one origin (the common case) → still uses
///    `getTotalStepsInInterval`'s aggregate, since Health Connect's
///    own aggregation correctly de-duplicates overlapping records
///    *within* a single origin (e.g. a source that logs both live
///    increments and periodic corrections) — a naive re-sum of raw
///    records wouldn't reliably do that, so the platform aggregate is
///    still the better answer for a single source, matching Health
///    Connect's own recommended usage.
///  - More than one origin → sums each origin's records separately and
///    takes the LARGEST single origin's total, instead of the sum of
///    all of them. This assumes overlapping trackers are recording the
///    same physical activity rather than genuinely additive activity,
///    which is the standard mitigation for Health Connect's
///    documented lack of cross-app deduplication, and is what brings
///    the displayed number back in line with what a single app like
///    Google Fit shows.
class HealthConnectProvider implements ActivityProvider {
  HealthConnectProvider() : _health = Health();

  final Health _health;

  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.TOTAL_CALORIES_BURNED,
  ];

  static const _permissions = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  @override
  String get id => 'health_connect';

  @override
  Future<ActivityAvailability> checkAvailability() async {
    await _ensureConfigured();
    try {
      final available = await _health.isHealthConnectAvailable();
      return available
          ? ActivityAvailability.available
          : ActivityAvailability.unavailable;
    } catch (e) {
      debugPrint('HealthConnectProvider: checkAvailability failed: $e');
      return ActivityAvailability.unavailable;
    }
  }

  @override
  Future<bool> hasPermission() async {
    await _ensureConfigured();
    try {
      final hasSteps = await _health.hasPermissions(
        _types,
        permissions: _permissions,
      );
      return hasSteps ?? false;
    } catch (e) {
      debugPrint('HealthConnectProvider: hasPermission failed: $e');
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    await _ensureConfigured();
    try {
      // Health Connect will not surface step data at all unless the OS
      // ACTIVITY_RECOGNITION runtime permission is also granted — this
      // is a plain Android permission (not part of Health Connect's own
      // permission screen), requested separately via permission_handler
      // per the health package's own setup docs.
      final activityStatus = await Permission.activityRecognition.request();
      if (!activityStatus.isGranted) return false;

      return await _health.requestAuthorization(
        _types,
        permissions: _permissions,
      );
    } catch (e) {
      debugPrint('HealthConnectProvider: requestPermission failed: $e');
      return false;
    }
  }

  @override
  Future<List<DailyActivity>> readDailyActivity({
    required DateTime start,
    required DateTime end,
  }) async {
    await _ensureConfigured();
    final results = <DailyActivity>[];

    // One day at a time — getTotalStepsInInterval/getHealthDataFromTypes
    // both aggregate over whatever range they're given, so a per-day
    // loop is what turns that into the per-calendar-day rows
    // daily_activity_summary needs (UNIQUE(user_id, date)), rather than
    // one big multi-day blob this app would have to re-split itself.
    for (
      var day = DateTime(start.year, start.month, start.day);
      !day.isAfter(DateTime(end.year, end.month, end.day));
      day = day.add(const Duration(days: 1))
    ) {
      final dayStart = day;
      final dayEnd = day.add(const Duration(days: 1));

      try {
        final points = await _health.getHealthDataFromTypes(
          types: const [
            HealthDataType.STEPS,
            HealthDataType.DISTANCE_DELTA,
            HealthDataType.TOTAL_CALORIES_BURNED,
          ],
          startTime: dayStart,
          endTime: dayEnd,
        );

        final stepPoints =
            points.where((p) => p.type == HealthDataType.STEPS).toList();
        final steps = await _resolveStepCount(dayStart, dayEnd, stepPoints);

        var distanceMeters = 0.0;
        var calories = 0.0;
        for (final point in points) {
          final value = point.value;
          if (value is! NumericHealthValue) continue;
          if (point.type == HealthDataType.DISTANCE_DELTA) {
            distanceMeters += value.numericValue.toDouble();
          } else if (point.type == HealthDataType.TOTAL_CALORIES_BURNED) {
            calories += value.numericValue.toDouble();
          }
        }

        // Active Time: Health Connect API level limitations across various Android targets
        // mean EXERCISE_SESSION durations require additional workout permissions.
        // TOTAL_CALORIES_BURNED is used as an active time proxy (estimating ~1 active min
        // per 5 burned calories when active) until direct EXERCISE_SESSION integration.
        final activeMinutes = (calories / 5.0).round();

        if (steps == 0 && distanceMeters == 0 && calories == 0) continue;

        results.add(
          DailyActivity(
            date: day,
            steps: steps,
            distanceKm: distanceMeters / 1000,
            calories: calories,
            activeMinutes: activeMinutes,
          ),
        );
      } catch (e) {
        // One bad day shouldn't abort the whole sync window — skip and
        // let the rest of the range still sync; the failed day just
        // gets picked up again on the next sync.
        debugPrint(
          'HealthConnectProvider: failed to read ${day.toIso8601String()}: $e',
        );
      }
    }

    return results;
  }

  /// Decides one day's step count from raw [stepPoints] — see this
  /// class's doc for the full reasoning. Single origin: trust Health
  /// Connect's own aggregate (correct within-origin dedup). Multiple
  /// origins: sum per origin and take the largest, rather than the
  /// platform aggregate's sum-of-everything.
  Future<int> _resolveStepCount(
    DateTime dayStart,
    DateTime dayEnd,
    List<HealthDataPoint> stepPoints,
  ) async {
    final origins = stepPoints.map((p) => p.sourceName).toSet();

    if (origins.length <= 1) {
      try {
        final aggregated = await _health.getTotalStepsInInterval(
          dayStart,
          dayEnd,
        );
        if (aggregated != null) return aggregated;
      } catch (e) {
        debugPrint(
          'HealthConnectProvider: aggregate step read failed for '
          '${dayStart.toIso8601String()}, falling back to raw records: $e',
        );
      }
    } else {
      debugPrint(
        'HealthConnectProvider: ${origins.length} step data origins for '
        '${dayStart.toIso8601String()}: $origins — using the single '
        'largest origin instead of summing all of them (see class doc).',
      );
    }

    final totalsByOrigin = <String, int>{};
    for (final point in stepPoints) {
      final value = point.value;
      if (value is! NumericHealthValue) continue;
      totalsByOrigin.update(
        point.sourceName,
        (existing) => existing + value.numericValue.round(),
        ifAbsent: () => value.numericValue.round(),
      );
    }
    if (totalsByOrigin.isEmpty) return 0;
    return totalsByOrigin.values.reduce((a, b) => a > b ? a : b);
  }

  @override
  Future<void> openProviderSettings() async {
    await _ensureConfigured();
    try {
      await _health.installHealthConnect();
    } catch (e) {
      debugPrint('HealthConnectProvider: openProviderSettings failed: $e');
    }
  }
}
