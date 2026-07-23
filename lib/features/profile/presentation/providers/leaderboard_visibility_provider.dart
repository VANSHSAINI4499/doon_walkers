import 'dart:async';

import 'package:doon_walkers/features/auth/data/repositories/user_repository_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Riverpod AsyncNotifier managing the "Show me on leaderboards"
/// toggle (Version 2, Phase C3). No explicit invalidation needed after
/// a successful update — `currentUserProvider` streams the caller's
/// own `public.users` row live (Realtime is already enabled on that
/// table), so the new value propagates on its own the moment the
/// write commits.
final leaderboardVisibilityControllerProvider = AsyncNotifierProvider<LeaderboardVisibilityController, void>(
  LeaderboardVisibilityController.new,
  name: 'leaderboardVisibilityControllerProvider',
);

class LeaderboardVisibilityController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> setShowOnLeaderboard(bool value) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      await ref.read(userRepositoryProvider).updateShowOnLeaderboard(value);
      success = true;
    });
    return success;
  }
}
