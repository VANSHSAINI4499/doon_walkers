import 'dart:async';

import 'package:doon_walkers/core/providers/shared_preferences_provider.dart';
import 'package:doon_walkers/features/challenges/data/repositories/challenge_repository_impl.dart';
import 'package:doon_walkers/features/challenges/data/services/challenge_celebration_tracker.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_progress.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_tier_achievement.dart';
import 'package:doon_walkers/features/challenges/domain/entities/leaderboard_entry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// All challenges (active + draft) — admin management list only. There
/// is no public "active challenges" provider yet in this phase (no
/// Challenges tab to feed — that's C2); RLS already correctly scopes
/// what a non-admin would get back if one were added later.
///
/// One-shot fetch, not a live stream — same reasoning as every other
/// small admin-managed list in this project (treks, products).
final adminAllChallengesProvider = FutureProvider<List<Challenge>>(
  (ref) => ref.watch(challengeRepositoryProvider).fetchAllChallenges(),
  name: 'adminAllChallengesProvider',
);

/// Active challenges only — feeds the public Challenges tab
/// (Version 2, Phase C2) for guests/members. Mirrors
/// publishedTreksProvider/adminAllTreksProvider's split; ChallengesScreen
/// picks between this and [adminAllChallengesProvider] purely on
/// [isAdminProvider], same as TrekLibraryScreen.
final activeChallengesProvider = FutureProvider<List<Challenge>>(
  (ref) => ref.watch(challengeRepositoryProvider).fetchActiveChallenges(),
  name: 'activeChallengesProvider',
);

/// A single challenge by id, for the admin edit form. `autoDispose`
/// since the form is visited transiently, same reasoning as
/// `trekByIdProvider`/`productByIdProvider`.
final challengeByIdProvider = FutureProvider.autoDispose.family<Challenge?, String>(
  (ref, id) => ref.watch(challengeRepositoryProvider).fetchChallengeById(id),
  name: 'challengeByIdProvider',
);

/// The signed-in user's own progress across every active challenge —
/// not consumed by any UI yet this phase (no Challenges tab — that's
/// C2), but part of the data layer this phase explicitly delivers, and
/// this is how its correctness gets verified through the app's normal
/// repository/provider stack rather than only via direct SQL.
final myChallengeProgressProvider = FutureProvider<List<ChallengeProgress>>(
  (ref) => ref.watch(challengeRepositoryProvider).fetchMyProgress(),
  name: 'myChallengeProgressProvider',
);

/// The signed-in user's full tier-achievement history — feeds Personal
/// Challenge History (Version 2, Phase C2) and, via
/// ChallengeCelebrationTracker, the completion-animation "newly
/// achieved" check. Empty (not an error) for a guest, same as
/// [myChallengeProgressProvider] — the underlying RPC returns no rows
/// rather than failing when auth.uid() is null.
final myTierHistoryProvider = FutureProvider<List<ChallengeTierAchievement>>(
  (ref) => ref.watch(challengeRepositoryProvider).fetchMyTierHistory(),
  name: 'myTierHistoryProvider',
);

final challengeCelebrationTrackerProvider = Provider<ChallengeCelebrationTracker>(
  (ref) => ChallengeCelebrationTracker(ref.watch(sharedPreferencesProvider)),
  name: 'challengeCelebrationTrackerProvider',
);

/// One challenge's leaderboard (Version 2, Phase C3) — `autoDispose`
/// since the leaderboard screen is visited transiently, same
/// reasoning as [challengeByIdProvider]. Safe for a guest to watch —
/// see ChallengeRepository.fetchLeaderboard's doc.
final challengeLeaderboardProvider = FutureProvider.autoDispose.family<List<LeaderboardEntry>, String>(
  (ref, challengeId) => ref.watch(challengeRepositoryProvider).fetchLeaderboard(challengeId),
  name: 'challengeLeaderboardProvider',
);

/// Riverpod AsyncNotifier managing admin challenge mutations (create,
/// update, delete, active toggle). Mirrors ProductAdminController's
/// shape.
final challengeAdminControllerProvider = AsyncNotifierProvider<ChallengeAdminController, void>(
  ChallengeAdminController.new,
  name: 'challengeAdminControllerProvider',
);

class ChallengeAdminController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<Challenge?> createChallenge({
    required String title,
    required String description,
    required ChallengeMetric metric,
    required ChallengeTimeWindow timeWindow,
    DateTime? startDate,
    DateTime? endDate,
    String? icon,
    required Map<ChallengeTier, double> tierThresholds,
  }) async {
    state = const AsyncLoading();
    Challenge? created;
    state = await AsyncValue.guard(() async {
      created = await ref.read(challengeRepositoryProvider).createChallenge(
            title: title,
            description: description,
            metric: metric,
            timeWindow: timeWindow,
            startDate: startDate,
            endDate: endDate,
            icon: icon,
            tierThresholds: tierThresholds,
          );
    });
    if (created != null) ref.invalidate(adminAllChallengesProvider);
    return created;
  }

  Future<bool> updateChallenge({
    required String id,
    required String title,
    required String description,
    required ChallengeMetric metric,
    required ChallengeTimeWindow timeWindow,
    DateTime? startDate,
    DateTime? endDate,
    String? icon,
    required Map<ChallengeTier, double> tierThresholds,
  }) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      await ref.read(challengeRepositoryProvider).updateChallenge(
            id: id,
            title: title,
            description: description,
            metric: metric,
            timeWindow: timeWindow,
            startDate: startDate,
            endDate: endDate,
            icon: icon,
            tierThresholds: tierThresholds,
          );
      success = true;
    });
    if (success) {
      ref.invalidate(adminAllChallengesProvider);
      ref.invalidate(challengeByIdProvider(id));
    }
    return success;
  }

  Future<bool> deleteChallenge(String id) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      await ref.read(challengeRepositoryProvider).deleteChallenge(id);
      success = true;
    });
    if (success) ref.invalidate(adminAllChallengesProvider);
    return success;
  }

  Future<bool> setActive(String id, bool isActive) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      await ref.read(challengeRepositoryProvider).setActive(id, isActive);
      success = true;
    });
    if (success) {
      ref.invalidate(adminAllChallengesProvider);
      ref.invalidate(challengeByIdProvider(id));
    }
    return success;
  }
}
