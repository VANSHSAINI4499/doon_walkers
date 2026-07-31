import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The home screen's streak indicator (Part 4) — "🔥 N" rather than a
/// bare icon, reading [myActivityStreakProvider] directly so it always
/// reflects the latest value after a sync invalidates that provider,
/// with no state of its own to fall out of sync.
///
/// Two distinct animations, both intentional:
///  - the NUMBER counts up from its previous value to the new one
///    (`TweenAnimationBuilder`'s standard behaviour — it self-animates
///    from whatever it last displayed, not from zero, on every
///    rebuild with a different target).
///  - the whole badge PULSES once, on top of that, specifically when
///    the value goes up — a `TweenAnimationBuilder` alone wouldn't
///    give the "premium" bounce the brief asks for, just a smooth
///    count.
class StreakBadge extends ConsumerStatefulWidget {
  const StreakBadge({super.key});

  @override
  ConsumerState<StreakBadge> createState() => _StreakBadgeState();
}

class _StreakBadgeState extends ConsumerState<StreakBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;
  int? _lastSeenStreak;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: AppMotion.slow,
    );
    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.3,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.3,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 60,
      ),
    ]).animate(_pulseController);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final streakAsync = ref.watch(myActivityStreakProvider);
    final streak = streakAsync.valueOrNull;

    if (streak != null) {
      final previous = _lastSeenStreak;
      if (previous != null && streak > previous) {
        // Deferred to after this frame — starting an animation mid-
        // build would try to schedule a rebuild during the current
        // one.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _pulseController.forward(from: 0);
        });
      }
      _lastSeenStreak = streak;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push(AppConstants.routeStreakDetails),
      child: AnimatedBuilder(
        animation: _pulseScale,
        builder:
            (context, child) =>
                Transform.scale(scale: _pulseScale.value, child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: palette.primarySubtle,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedStreakFlame(
                icon: AppIcons.streak,
                color: palette.primary,
                size: 18,
                isActive: (streak ?? 0) > 0,
              ),
              const SizedBox(width: AppSpacing.xs),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: streak ?? 0),
                duration: AppMotion.medium,
                curve: AppMotion.emphasized,
                builder:
                    (context, value, _) => Text(
                      '$value',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: palette.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
