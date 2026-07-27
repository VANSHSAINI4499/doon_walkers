import 'dart:math';

import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/tier_badge.dart';
import 'package:flutter/material.dart';

/// Shows the "new tier achieved" celebration for [challenge]/[tier] and
/// resolves once it's dismissed (tap or auto-dismiss after ~2.5s) — a
/// caller processing a queue of several simultaneous achievements should
/// `await` this before showing the next one, keeping them from
/// overlapping.
///
/// Redesign 2.0 Phase 12 recuts the visual calm: a flat card with a
/// tier-tinted hairline instead of a glowing frosted panel, and a smaller,
/// quieter burst. **This is presentation only.** The trigger (a genuine
/// new-tier achievement, detected in ChallengesScreen via
/// `isNewlyAchievedTier` against the persisted baseline) is untouched;
/// this function is just how that already-decided celebration is drawn.
///
/// ## Why this keeps its animation when the rest of the app lost theirs
///
/// The calm direction rules out ambient and decorative motion. A
/// celebration is neither: it fires a handful of times a month, only on a
/// genuine achievement, and the motion *is* the message — a static "you
/// reached Gold" card would not read as a moment. So the badge pop and the
/// burst stay, toned down (12 particles, no glow, tighter travel) rather
/// than removed.
///
/// Still a custom AnimationController rather than a confetti package —
/// Flutter's own primitives cover a badge pop plus a small burst.
Future<void> showTierCelebration(
  BuildContext context, {
  required Challenge challenge,
  required ChallengeTier tier,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: AppPalette.of(context).scrim,
    transitionDuration: AppMotion.medium,
    pageBuilder:
        (context, animation, secondaryAnimation) =>
            _TierCelebrationDialog(challenge: challenge, tier: tier),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.emphasized,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _TierCelebrationDialog extends StatefulWidget {
  const _TierCelebrationDialog({required this.challenge, required this.tier});

  final Challenge challenge;
  final ChallengeTier tier;

  @override
  State<_TierCelebrationDialog> createState() => _TierCelebrationDialogState();
}

class _TierCelebrationDialogState extends State<_TierCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _badgeScale;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _badgeScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.6, curve: Curves.elasticOut),
    );
    _particles = _generateParticles(TierBadge.colorFor(widget.tier));

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  /// 12 particles in the tier's own colour only — the old version mixed in
  /// white, which on a light background was invisible and on a dark one
  /// read as a second, competing effect.
  List<_Particle> _generateParticles(Color tierColor) {
    final random = Random();
    const count = 12;
    return List.generate(count, (i) {
      final angle = (2 * pi / count) * i + random.nextDouble() * 0.3;
      final distance = 52 + random.nextDouble() * 28;
      return _Particle(
        angle: angle,
        distance: distance,
        color: i.isEven ? tierColor : tierColor.withValues(alpha: 0.6),
        radius: 2 + random.nextDouble() * 1.5,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final tierColor = TierBadge.colorFor(widget.tier);

    return Center(
      child: GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        child: SizedBox(
          width: 300,
          child: AppCard(
            borderColor: tierColor.withValues(alpha: 0.55),
            elevation: 3,
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.xxl,
              horizontal: AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'NEW TIER ACHIEVED',
                  style: AppTextStyles.overline.copyWith(color: tierColor),
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: 132,
                  height: 132,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder:
                        (context, child) => CustomPaint(
                          painter: _ParticleBurstPainter(
                            particles: _particles,
                            progress: _controller.value,
                          ),
                          child: Center(
                            child: Transform.scale(
                              scale: _badgeScale.value,
                              child: child,
                            ),
                          ),
                        ),
                    child: TierBadgeIcon(tier: widget.tier, size: 72),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  widget.tier.label,
                  style: AppTextStyles.headlineSmall.copyWith(color: tierColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.challenge.title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: palette.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Tap to continue',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: palette.textDisabled,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.distance,
    required this.color,
    required this.radius,
  });

  final double angle;
  final double distance;
  final Color color;
  final double radius;
}

/// Radial burst — each particle travels outward along its own [angle] and
/// fades out, driven entirely by [progress] (0.0 to 1.0).
class _ParticleBurstPainter extends CustomPainter {
  _ParticleBurstPainter({required this.particles, required this.progress});

  final List<_Particle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = size.center(Offset.zero);
    // Particles travel during the first 70% of the animation, then hold
    // position while fading out over the remainder.
    final travel = (progress / 0.7).clamp(0.0, 1.0);
    const fadeStart = 0.4;
    final opacity =
        progress <= fadeStart
            ? 1.0
            : (1 - ((progress - fadeStart) / (1 - fadeStart))).clamp(0.0, 1.0);
    if (opacity <= 0) return;

    for (final particle in particles) {
      final offset =
          center +
          Offset(cos(particle.angle), sin(particle.angle)) *
              (particle.distance * travel);
      final paint = Paint()..color = particle.color.withValues(alpha: opacity);
      canvas.drawCircle(offset, particle.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticleBurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
