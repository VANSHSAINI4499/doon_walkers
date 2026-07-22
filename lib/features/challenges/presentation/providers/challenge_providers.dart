import 'dart:async';

import 'package:doon_walkers/features/challenges/data/repositories/challenge_repository_impl.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_progress.dart';
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
