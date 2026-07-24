import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/activity/presentation/providers/activity_providers.dart';
import 'package:doon_walkers/features/activity/presentation/widgets/activity_permission_banner.dart';
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

/// Challenges — one shared screen for every role, mirroring
/// TrekLibraryScreen: guests/members see active challenges only, an admin
/// sees the same screen plus inline management (drafts included and
/// marked, a per-challenge actions menu, an "Add Challenge" FAB).
///
/// Redesign Phase 4 rebuilds the presentation on the design system
/// (skeleton loading, glass cards, gradient FAB). **The celebration
/// detection — the `ref.listen` on live progress, the
/// [isNewlyAchievedTier] diff against the persisted per-device baseline,
/// and the queued overlay — is unchanged**, as are the role split and the
/// pull-to-refresh sync chain.
class ChallengesScreen extends ConsumerStatefulWidget {
  const ChallengesScreen({super.key});

  @override
  ConsumerState<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends ConsumerState<ChallengesScreen> {
  bool _celebrationQueueRunning = false;

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final challengesProvider = isAdmin ? adminAllChallengesProvider : activeChallengesProvider;
    final challengesAsync = ref.watch(challengesProvider);
    final progressAsync = ref.watch(myChallengeProgressProvider);

    // Fires only on a real data change (a FutureProvider's value actually
    // changing), never on a plain rebuild — see ChallengeCelebrationTracker
    // for why that, combined with a persisted per-device baseline, keeps
    // this from re-celebrating the same tier on every screen visit.
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
            icon: const AppIcon(AppIcons.medal, color: AppColors.white),
            tooltip: 'My Achievements',
            onPressed: () => context.push(AppConstants.routeChallengeHistory),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? _AddChallengeFab(onTap: () => context.push(AppConstants.routeAdminChallengesNew))
          : null,
      body: SafeArea(
        child: Column(
          children: [
            const ActivityPermissionBanner(),
            Expanded(child: _buildChallengesList(challengesAsync, challengesProvider, progressAsync, isAdmin)),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengesList(
    AsyncValue<List<Challenge>> challengesAsync,
    FutureProvider<List<Challenge>> challengesProvider,
    AsyncValue<List<ChallengeProgress>> progressAsync,
    bool isAdmin,
  ) {
    return challengesAsync.when(
      loading: () => const _ChallengeListSkeleton(),
      error: (error, stack) {
        debugPrint('ChallengesScreen: failed to load challenges: $error');
        return _ChallengesError(onRetry: () => ref.invalidate(challengesProvider));
      },
      data: (challenges) {
        // Pull-to-refresh doubles as one of the three sync triggers
        // (launch/resume/manual) — chained so the refresh spinner stays up
        // until fresh activity data has actually landed, not just the
        // challenge list itself.
        Future<void> onRefresh() {
          return ref.read(activitySyncControllerProvider.notifier).sync().then((_) {
            ref.invalidate(myChallengeProgressProvider);
            return ref.refresh(challengesProvider.future);
          });
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
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              isAdmin ? 96 : AppSpacing.lg,
            ),
            itemCount: challenges.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final challenge = challenges[index];
              return AppReveal(
                index: index.clamp(0, 8),
                child: ChallengeCard(
                  challenge: challenge,
                  progress: progressByChallenge[challenge.id],
                  onTap: () => context.push(AppConstants.challengeDetailLocation(challenge.id)),
                  adminActions: isAdmin ? ChallengeAdminActions(challenge: challenge) : null,
                ),
              );
            },
          ),
        );
      },
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

/// Gradient "Add Challenge" button — the design system's extended FAB.
/// Admin-only; the caller gates it (RLS gates the writes it leads to).
class _AddChallengeFab extends StatelessWidget {
  const _AddChallengeFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          gradient: AppGradients.primary,
          borderRadius: BorderRadius.circular(AppRadius.button),
          boxShadow: AppShadows.button(AppColors.primary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon(AppIcons.add, size: 22, color: AppColors.onPrimary),
            const SizedBox(width: AppSpacing.sm),
            Text('Add Challenge', style: AppTextStyles.tinted(AppTextStyles.labelLarge, AppColors.onPrimary)),
          ],
        ),
      ),
    );
  }
}

class _ChallengesError extends StatelessWidget {
  const _ChallengesError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon(AppIcons.error, size: 44, color: AppColors.danger),
            const SizedBox(height: AppSpacing.md),
            Text('Could not load challenges.', style: AppTextStyles.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xl),
            PremiumButton(
              label: 'Retry',
              icon: AppIcons.refresh,
              variant: PremiumButtonVariant.glass,
              size: PremiumButtonSize.small,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChallenges extends StatelessWidget {
  const _EmptyChallenges({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: const AppIcon(AppIcons.challenges, size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            isAdmin ? 'No challenges yet' : 'No challenges yet — check back soon',
            style: AppTextStyles.titleLarge,
            textAlign: TextAlign.center,
          ),
          if (isAdmin) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Tap "Add Challenge" to create the first one.',
              style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Challenge-card-shaped placeholders while the list loads.
class _ChallengeListSkeleton extends StatelessWidget {
  const _ChallengeListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: 4,
        separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) => Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SkeletonCircle(size: 44),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 140, height: 16),
                        SizedBox(height: AppSpacing.sm),
                        SkeletonBox(width: 200, height: 10),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.lg),
              SkeletonBox(height: 8, borderRadius: AppRadius.pill),
              SizedBox(height: AppSpacing.sm),
              SkeletonBox(width: 160, height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
