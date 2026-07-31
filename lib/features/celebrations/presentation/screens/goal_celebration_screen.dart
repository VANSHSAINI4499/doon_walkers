import 'package:confetti/confetti.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Full-screen celebration pushed by [ActivitySyncController] the
/// moment a sync crosses today's step goal for the first time (Part 2
/// of the celebration brief). Presentation only — the "did this really
/// just happen, for the first time today" decision is
/// [didCrossDailyGoal] + [CelebrationTracker], both already resolved
/// before this screen is ever pushed.
///
/// A genuine full screen (pushed route), not a dialog — unlike the
/// smaller [showTierCelebration] popup, the brief explicitly asks for
/// a Pacer-style full-screen moment here. [confetti] renders the dense
/// full-screen burst that popup's small hand-rolled particle system
/// was never meant to scale to.
class GoalCelebrationScreen extends StatefulWidget {
  const GoalCelebrationScreen({
    super.key,
    required this.steps,
    required this.goal,
  });

  final int steps;
  final int goal;

  @override
  State<GoalCelebrationScreen> createState() => _GoalCelebrationScreenState();
}

class _GoalCelebrationScreenState extends State<GoalCelebrationScreen> {
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

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

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
                      child: AppIcon(
                        AppIcons.medal,
                        size: 88,
                        color: palette.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      '🎉 Goal Achieved',
                      style: AppTextStyles.headlineMedium.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _AnimatedStepCount(steps: widget.steps, goal: widget.goal),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Fantastic!\nYou completed today\'s walking goal.',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: palette.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(),
                    AppButton(
                      label: 'Continue',
                      fullWidth: true,
                      onPressed: () => context.pop(),
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

/// Counts up from 0 to [steps] on first appear — [TweenAnimationBuilder]
/// only ever animates once here since this screen is never rebuilt
/// with a different value (it's a one-shot celebration, not a live
/// dashboard tile).
class _AnimatedStepCount extends StatelessWidget {
  const _AnimatedStepCount({required this.steps, required this.goal});

  final int steps;
  final int goal;

  static String _withThousandsSeparator(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: steps),
      duration: AppMotion.slow,
      curve: AppMotion.emphasized,
      builder: (context, value, _) {
        return RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: AppTextStyles.statXLarge.copyWith(
              color: palette.primary,
              fontWeight: FontWeight.bold,
            ),
            children: [
              TextSpan(text: _withThousandsSeparator(value)),
              TextSpan(
                text: ' / ${_withThousandsSeparator(goal)} Steps',
                style: AppTextStyles.titleMedium.copyWith(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
