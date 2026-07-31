// SharedPreferences-backed persistence round-trip — the pragmatic
// app-restart/reboot-resume path (TripTrackingResumeProvider) depends
// entirely on an active session surviving a JSON encode/decode cycle,
// and on a malformed/stale value degrading to "no session" rather than
// crashing startup.

import 'package:doon_walkers/features/trip_tracking/data/repositories/trip_tracking_repository_impl.dart';
import 'package:doon_walkers/features/trip_tracking/domain/entities/navigation_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

NavigationSession _session() => NavigationSession(
  id: 'session-1',
  destinationName: 'George Everest Peak',
  destinationLat: 30.4448,
  destinationLng: 77.9853,
  startedAt: DateTime(2026, 7, 30, 8, 0),
  startLat: 30.35,
  startLng: 78.05,
  distanceTravelledKm: 4.2,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TripTrackingRepositoryImpl', () {
    test('getActiveSession returns null when nothing is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = TripTrackingRepositoryImpl(await SharedPreferences.getInstance());
      expect(await repo.getActiveSession(), isNull);
    });

    test('saveActiveSession/getActiveSession round-trips every field', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = TripTrackingRepositoryImpl(await SharedPreferences.getInstance());
      final session = _session();

      await repo.saveActiveSession(session);
      final loaded = await repo.getActiveSession();

      expect(loaded, isNotNull);
      expect(loaded!.id, session.id);
      expect(loaded.destinationName, session.destinationName);
      expect(loaded.destinationLat, session.destinationLat);
      expect(loaded.destinationLng, session.destinationLng);
      expect(loaded.startedAt, session.startedAt);
      expect(loaded.distanceTravelledKm, session.distanceTravelledKm);
      expect(loaded.status, NavigationSessionStatus.active);
    });

    test('clearActiveSession removes the stored session', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = TripTrackingRepositoryImpl(await SharedPreferences.getInstance());
      await repo.saveActiveSession(_session());

      await repo.clearActiveSession();

      expect(await repo.getActiveSession(), isNull);
    });

    test('a malformed stored value degrades to null instead of throwing', () async {
      SharedPreferences.setMockInitialValues({
        'active_navigation_session': 'not valid json{{{',
      });
      final repo = TripTrackingRepositoryImpl(await SharedPreferences.getInstance());

      expect(await repo.getActiveSession(), isNull);
    });
  });
}
