import 'dart:convert';

import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/shared_preferences_provider.dart';
import 'package:doon_walkers/features/trip_tracking/domain/entities/navigation_session.dart';
import 'package:doon_walkers/features/trip_tracking/domain/repositories/trip_tracking_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Riverpod provider exposing the implementation of
/// [TripTrackingRepository].
final tripTrackingRepositoryProvider = Provider<TripTrackingRepository>(
  (ref) => TripTrackingRepositoryImpl(ref.watch(sharedPreferencesProvider)),
  name: 'tripTrackingRepositoryProvider',
);

/// SharedPreferences-backed [TripTrackingRepository] — same DI/storage
/// convention as [AppConstants.prefsHasSeenOnboarding], just JSON-
/// encoded instead of a bare bool. Local-only by design; see the
/// abstract interface's doc.
class TripTrackingRepositoryImpl implements TripTrackingRepository {
  const TripTrackingRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<NavigationSession?> getActiveSession() async {
    final raw = _prefs.getString(AppConstants.prefsActiveNavigationSession);
    if (raw == null) return null;
    try {
      return NavigationSession.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (e) {
      // Malformed/stale value (e.g. from a previous app version's shape)
      // shouldn't crash startup — treat as "no active session".
      debugPrint('[TripTracking] getActiveSession: failed to decode: $e');
      return null;
    }
  }

  @override
  Future<void> saveActiveSession(NavigationSession session) async {
    await _prefs.setString(
      AppConstants.prefsActiveNavigationSession,
      jsonEncode(session.toJson()),
    );
  }

  @override
  Future<void> clearActiveSession() async {
    await _prefs.remove(AppConstants.prefsActiveNavigationSession);
  }
}
