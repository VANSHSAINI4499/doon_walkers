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
      return available ? ActivityAvailability.available : ActivityAvailability.unavailable;
    } catch (e) {
      debugPrint('HealthConnectProvider: checkAvailability failed: $e');
      return ActivityAvailability.unavailable;
    }
  }

  @override
  Future<bool> hasPermission() async {
    await _ensureConfigured();
    try {
      final hasSteps = await _health.hasPermissions(_types, permissions: _permissions);
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

      return await _health.requestAuthorization(_types, permissions: _permissions);
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
    for (var day = DateTime(start.year, start.month, start.day);
        !day.isAfter(DateTime(end.year, end.month, end.day));
        day = day.add(const Duration(days: 1))) {
      final dayStart = day;
      final dayEnd = day.add(const Duration(days: 1));

      try {
        final steps = await _health.getTotalStepsInInterval(dayStart, dayEnd) ?? 0;

        final distanceAndCalories = await _health.getHealthDataFromTypes(
          types: const [HealthDataType.DISTANCE_DELTA, HealthDataType.TOTAL_CALORIES_BURNED],
          startTime: dayStart,
          endTime: dayEnd,
        );

        var distanceMeters = 0.0;
        var calories = 0.0;
        for (final point in distanceAndCalories) {
          final value = point.value;
          if (value is! NumericHealthValue) continue;
          if (point.type == HealthDataType.DISTANCE_DELTA) {
            distanceMeters += value.numericValue.toDouble();
          } else if (point.type == HealthDataType.TOTAL_CALORIES_BURNED) {
            calories += value.numericValue.toDouble();
          }
        }

        if (steps == 0 && distanceMeters == 0 && calories == 0) continue;

        results.add(DailyActivity(
          date: day,
          steps: steps,
          distanceKm: distanceMeters / 1000,
          calories: calories,
        ));
      } catch (e) {
        // One bad day shouldn't abort the whole sync window — skip and
        // let the rest of the range still sync; the failed day just
        // gets picked up again on the next sync.
        debugPrint('HealthConnectProvider: failed to read ${day.toIso8601String()}: $e');
      }
    }

    return results;
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
