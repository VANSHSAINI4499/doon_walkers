import 'package:confetti/confetti.dart';
import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/activity/presentation/providers/activity_dashboard_providers.dart';
import 'package:doon_walkers/features/celebrations/presentation/widgets/weekly_streak_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Full-screen celebration pushed by [ActivitySyncController] when a
/// sync grows the activity streak (Part 3). Same presentation-only
/// split as [GoalCelebrationScreen] — the "did the streak really just
/// increase" decision is [didStreakIncrease] + [CelebrationTracker],
/// already resolved before this is pushed.
///
/// Deliberately reuses [AnimatedStreakFlame] (just sized up) rather
/// than a second flame animation, and `palette.primary` rather than a
/// custom flame colour — [StreakSection]'s own doc already establishes
/// why this app keeps one accent for streaks rather than a
/// second-brand orange.
class StreakCelebrationScreen extends ConsumerStatefulWidget {
  const StreakCelebrationScreen({super.key, required this.streakCount});

  final int streakCount;

  @override
  ConsumerState<StreakCelebrationScreen> createState() =>
      _StreakCelebrationScreenState();
}

class _StreakCelebrationScreenState
    extends ConsumerState<StreakCelebrationScreen> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    )..play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  String get _motivationalText =>
      widget.streakCount >= 7
          ? "You're unstoppable! Keep the streak alive."
          : "You're on fire! Keep moving to extend your streak.";

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final trailingWeekAsync = ref.watch(
      trailingWeekProvider(DateTime.now()),
    );

    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 24,
              maxBlastForce: 40,
              minBlastForce: 12,
              gravity: 0.25,
              colors: [
                palette.primary,
                palette.secondary,
                palette.accent,
                palette.gold,
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                children: [
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: palette.primarySubtle,
                      shape: BoxShape.circle,
                    ),
                    child: AnimatedStreakFlame(
                      icon: AppIcons.streak,
                      color: palette.primary,
                      size: 88,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    '${widget.streakCount}',
                    style: AppTextStyles.statXLarge.copyWith(
                      color: palette.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Day Streak',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  trailingWeekAsync.when(
                    data:
                        (days) => WeeklyStreakCalendar(days: days),
                    loading:
                        () => const SizedBox(
                          height: 60,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    _motivationalText,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: palette.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Continue',
                          variant: AppButtonVariant.glass,
                          onPressed: () => context.pop(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppButton(
                          label: 'View Streak Details',
                          onPressed: () {
                            context.pop();
                            context.push(AppConstants.routeStreakDetails);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
