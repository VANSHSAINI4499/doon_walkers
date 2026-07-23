import 'dart:async';

import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/activity/data/providers/health_connect_provider.dart';
import 'package:doon_walkers/features/activity/data/repositories/activity_repository_impl.dart';
import 'package:doon_walkers/features/activity/data/services/activity_sync_service.dart';
import 'package:doon_walkers/features/activity/domain/repositories/activity_provider.dart';
import 'package:doon_walkers/features/challenges/presentation/providers/challenge_providers.dart';
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
final activitySyncControllerProvider = AsyncNotifierProvider<ActivitySyncController, ActivitySyncOutcome?>(
  ActivitySyncController.new,
  name: 'activitySyncControllerProvider',
);

class ActivitySyncController extends AsyncNotifier<ActivitySyncOutcome?> {
  @override
  FutureOr<ActivitySyncOutcome?> build() => null;

  Future<ActivitySyncOutcome?> sync() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(activitySyncServiceProvider).sync());

    if (state.valueOrNull == ActivitySyncOutcome.success) {
      // Fresh activity data changes everything downstream: challenge
      // progress, tier history (celebration detection reads this via
      // myChallengeProgressProvider), and the last-synced timestamp.
      // Leaderboards aren't invalidated here — they're autoDispose and
      // re-fetch on their own each time a leaderboard screen is opened.
      ref.invalidate(myChallengeProgressProvider);
      ref.invalidate(myTierHistoryProvider);
      ref.invalidate(lastActivitySyncProvider);
      ref.invalidate(activityPermissionGrantedProvider);
    }

    return state.valueOrNull;
  }
}

/// Fire-and-forget side-effect provider: triggers a sync for the
/// app's whole lifetime whenever a live session exists — covers BOTH
/// "app launch, already signed in" and "just signed in." Watched once
/// from DoonWalkersApp, same pattern as pushTokenSyncProvider; nothing
/// ever reads its (meaningless) value.
final activityLaunchSyncProvider = Provider<void>(
  (ref) {
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
  },
  name: 'activityLaunchSyncProvider',
);
