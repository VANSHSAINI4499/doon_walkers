import 'dart:async';

import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/activity/data/providers/health_connect_provider.dart';
import 'package:doon_walkers/features/activity/data/repositories/activity_repository_impl.dart';
import 'package:doon_walkers/features/activity/data/services/activity_sync_service.dart';
import 'package:doon_walkers/features/activity/domain/repositories/activity_provider.dart';
import 'package:doon_walkers/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:doon_walkers/features/activity/presentation/providers/activity_dashboard_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The active [ActivityProvider] for this build. Android-only for now
/// — always [HealthConnectProvider]. A future platform check
/// (`Platform.isIOS ? AppleHealthProvider() : HealthConnectProvider()`)
/// is the ONLY place a second provider would ever need to be wired in;
/// nothing downstream (ActivitySyncService, the Challenge engine)
/// changes.
final activityProviderProvider = Provider<ActivityProvider>(
  (ref) => HealthConnectProvider(),
  name: 'activityProviderProvider',
);

final activitySyncServiceProvider = Provider<ActivitySyncService>(
  (ref) => ActivitySyncService(
    ref.watch(activityProviderProvider),
    ref.watch(activityRepositoryProvider),
  ),
  name: 'activitySyncServiceProvider',
);

/// Whether Health Connect (or whatever provider is active) is usable
/// on this device at all — drives ActivityPermissionBanner's
/// "install/update required" state.
final activityAvailabilityProvider = FutureProvider<ActivityAvailability>(
  (ref) => ref.watch(activityProviderProvider).checkAvailability(),
  name: 'activityAvailabilityProvider',
);

/// Whether read permission has already been granted, without
/// prompting — drives ActivityPermissionBanner's "grant permission"
/// vs. "synced" state.
final activityPermissionGrantedProvider = FutureProvider<bool>(
  (ref) => ref.watch(activityProviderProvider).hasPermission(),
  name: 'activityPermissionGrantedProvider',
);

/// When this user's activity was last successfully synced, or null if
/// never — shown in ActivityPermissionBanner as a freshness indicator.
final lastActivitySyncProvider = FutureProvider<DateTime?>(
  (ref) => ref.watch(activityRepositoryProvider).fetchLastSyncedAt(),
  name: 'lastActivitySyncProvider',
);

/// Riverpod AsyncNotifier driving every sync trigger described in the
/// Challenges Module pivot brief: launch, resume, and manual — all of
/// them just call [sync] here, so there is exactly one place that
/// decides what happens after a sync completes (invalidating the
/// providers that depend on fresh data).
///
/// Deliberately does NOT depend on a periodic WorkManager background
/// task — Android's Doze mode / OEM battery optimization makes that
/// unreliable across devices, so the feature is designed to work
/// correctly from launch/resume/manual sync alone. A daily WorkManager
/// task remains a valid future nice-to-have for extra freshness, not
/// implemented in this pass — see this phase's report for why it was
/// deliberately deferred rather than silently skipped.
final activitySyncControllerProvider =
    AsyncNotifierProvider<ActivitySyncController, ActivitySyncOutcome?>(
      ActivitySyncController.new,
      name: 'activitySyncControllerProvider',
    );

class ActivitySyncController extends AsyncNotifier<ActivitySyncOutcome?> {
  static DateTime? _lastSuccessfulSyncTime;

  @override
  FutureOr<ActivitySyncOutcome?> build() => null;

  /// Triggered automatically on screen visibility. Checks if we have already successfully
  /// synced today, and respects the 60-second cooldown to avoid redundant operations.
  Future<ActivitySyncOutcome?> autoSync() async {
    final now = DateTime.now();
    
    // Check if synced within the last 60 seconds (cooldown)
    if (_lastSuccessfulSyncTime != null) {
      final elapsed = now.difference(_lastSuccessfulSyncTime!);
      if (elapsed.inSeconds < 60) {
        debugPrint('[ActivitySync] autoSync: Skipping sync, cooldown active (${elapsed.inSeconds}s elapsed).');
        return ActivitySyncOutcome.success;
      }
    }

    // Check if the user has already granted permission. If not, request it.
    final hasPerm = await ref.read(activityProviderProvider).hasPermission();
    if (!hasPerm) {
      debugPrint('[ActivitySync] autoSync: Permission missing, requesting...');
      final granted = await ref.read(activityProviderProvider).requestPermission();
      if (!granted) {
        debugPrint('[ActivitySync] autoSync: Permission denied by user.');
        return ActivitySyncOutcome.permissionDenied;
      }
    }

    // Call sync (which handles the network request and invalidations)
    return sync(force: false);
  }

  Future<ActivitySyncOutcome?> sync({bool force = false}) async {
    final now = DateTime.now();

    // Check cooldown unless force is true (manual refresh)
    if (!force && _lastSuccessfulSyncTime != null) {
      final elapsed = now.difference(_lastSuccessfulSyncTime!);
      if (elapsed.inSeconds < 60) {
        debugPrint('[ActivitySync] sync: Cooldown active (${elapsed.inSeconds}s elapsed). Reusing cached data.');
        return ActivitySyncOutcome.success;
      }
    }

    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(activitySyncServiceProvider).sync(),
    );
    state = result;

    if (result.valueOrNull == ActivitySyncOutcome.success) {
      _lastSuccessfulSyncTime = now;
      
      // Invalidate everything downstream
      ref.invalidate(myChallengeProgressProvider);
      ref.invalidate(myTierHistoryProvider);
      ref.invalidate(lastActivitySyncProvider);
      ref.invalidate(activityPermissionGrantedProvider);
      ref.invalidate(activityRangeProvider);
      
      ref.invalidate(trailingWeekProvider);
      ref.invalidate(activityPercentileProvider);
      ref.invalidate(dailyPercentileProvider);
      ref.invalidate(bestDayProvider);
      ref.invalidate(activeDaysProvider);
      ref.invalidate(weeklyAggregatesProvider);
      ref.invalidate(monthComparisonProvider);
      
      ref.invalidate(myActivityStreakProvider);
      ref.invalidate(myUserPointsProvider);
      ref.invalidate(activeChallengesProvider);
      ref.invalidate(myEnrollmentsProvider);
      ref.invalidate(adminAllChallengesProvider);
    }

    return result.valueOrNull;
  }
}

/// Fire-and-forget side-effect provider: triggers a sync for the
/// app's whole lifetime whenever a live session exists — covers BOTH
/// "app launch, already signed in" and "just signed in." Watched once
/// from DoonWalkersApp, same pattern as pushTokenSyncProvider; nothing
/// ever reads its (meaningless) value.
final activityLaunchSyncProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<AuthState>>(
    authStateChangesProvider,
    (previous, next) {
      final event = next.valueOrNull?.event;
      final hasUser = Supabase.instance.client.auth.currentUser != null;
      if (hasUser &&
          (event == AuthChangeEvent.initialSession ||
              event == AuthChangeEvent.signedIn ||
              event == AuthChangeEvent.tokenRefreshed)) {
        ref.read(activitySyncControllerProvider.notifier).sync();
      }
    },
    // Same reasoning as pushTokenSyncProvider: without this, a
    // session already restored from disk before this listener
    // attaches means the initialSession event is never seen.
    fireImmediately: true,
  );
}, name: 'activityLaunchSyncProvider');
