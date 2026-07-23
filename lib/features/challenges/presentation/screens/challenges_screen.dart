import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/challenges/data/services/challenge_celebration_tracker.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_progress.dart';
import 'package:doon_walkers/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/challenge_admin_actions.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/challenge_card.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/tier_celebration_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Challenges — one shared screen for every role (Version 2, Phase
/// C2), mirroring TrekLibraryScreen exactly: guests/members see active
/// challenges only, an admin sees the same screen plus inline
/// management (drafts included and marked, a per-challenge actions
/// menu, an "Add Challenge" FAB). This is what replaced C1's separate
/// admin-only "Manage Challenges" tab — now that Challenges has a real
/// public tab, a second dedicated admin tab would push the nav bar
/// past the "5 tabs total for admin" ceiling for no reason, and the
/// inline-admin-controls pattern is this project's own established
/// convention anyway (Trek Library, Merchandise).
class ChallengesScreen extends ConsumerStatefulWidget {
  const ChallengesScreen({super.key});

  @override
  ConsumerState<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends ConsumerState<ChallengesScreen> {
  bool _celebrationQueueRunning = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAdmin = ref.watch(isAdminProvider);
    final challengesProvider = isAdmin ? adminAllChallengesProvider : activeChallengesProvider;
    final challengesAsync = ref.watch(challengesProvider);
    final progressAsync = ref.watch(myChallengeProgressProvider);

    // Fires only on a real data change (a FutureProvider's value
    // actually changing), never on a plain rebuild — see
    // ChallengeCelebrationTracker's doc for why that, combined with a
    // persisted per-device baseline, is what keeps this from
    // re-celebrating the same tier on every screen visit.
    ref.listen<AsyncValue<List<ChallengeProgress>>>(myChallengeProgressProvider, (previous, next) {
      final progressList = next.valueOrNull;
      if (progressList == null) return;
      final challenges = ref.read(challengesProvider).valueOrNull;
      if (challenges == null) return;
      _detectAndCelebrate(challenges, progressList);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Challenges'),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            tooltip: 'My Achievements',
            onPressed: () => context.push(AppConstants.routeChallengeHistory),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppConstants.routeAdminChallengesNew),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Challenge'),
            )
          : null,
      body: SafeArea(
        child: challengesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) {
            debugPrint('ChallengesScreen: failed to load challenges: $error');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 40, color: theme.colorScheme.error),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load challenges.',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(challengesProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          },
          data: (challenges) {
            Future<void> onRefresh() {
              ref.invalidate(myChallengeProgressProvider);
              return ref.refresh(challengesProvider.future);
            }

            if (challenges.isEmpty) {
              return RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [_EmptyChallenges(isAdmin: isAdmin)],
                ),
              );
            }

            final progressByChallenge = <String, ChallengeProgress>{
              for (final p in progressAsync.valueOrNull ?? const <ChallengeProgress>[]) p.challengeId: p,
            };

            return RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 16, 16, isAdmin ? 96 : 16),
                itemCount: challenges.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final challenge = challenges[index];
                  return ChallengeCard(
                    challenge: challenge,
                    progress: progressByChallenge[challenge.id],
                    onTap: () => context.push(AppConstants.challengeDetailLocation(challenge.id)),
                    adminActions: isAdmin ? ChallengeAdminActions(challenge: challenge) : null,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _detectAndCelebrate(
    List<Challenge> challenges,
    List<ChallengeProgress> progressList,
  ) async {
    if (_celebrationQueueRunning) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final tracker = ref.read(challengeCelebrationTrackerProvider);
    final newlyAchieved = <(Challenge, ChallengeTier)>[];

    for (final progress in progressList) {
      Challenge? challenge;
      for (final c in challenges) {
        if (c.id == progress.challengeId) {
          challenge = c;
          break;
        }
      }
      if (challenge == null) continue;

      final hadBaseline = tracker.hasBaseline(userId, challenge.id);
      final previous = tracker.lastSeenTier(userId, challenge.id);
      if (isNewlyAchievedTier(hadBaseline: hadBaseline, previous: previous, current: progress.currentTier)) {
        newlyAchieved.add((challenge, progress.currentTier!));
      }
      await tracker.markSeen(userId, challenge.id, progress.currentTier);
    }

    if (!mounted || newlyAchieved.isEmpty) return;

    _celebrationQueueRunning = true;
    for (final (challenge, tier) in newlyAchieved) {
      if (!mounted) break;
      await showTierCelebration(context, challenge: challenge, tier: tier);
    }
    _celebrationQueueRunning = false;
  }
}

class _EmptyChallenges extends StatelessWidget {
  const _EmptyChallenges({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_outlined, size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            isAdmin ? 'No challenges yet' : 'No challenges yet — check back soon',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          if (isAdmin) ...[
            const SizedBox(height: 8),
            Text(
              'Tap "Add Challenge" to create the first one.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
