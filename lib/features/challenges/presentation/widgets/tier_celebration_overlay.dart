import 'dart:math';

import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/tier_badge.dart';
import 'package:flutter/material.dart';

/// Shows the "new tier achieved" celebration for [challenge]/[tier] and
/// resolves once it's dismissed (tap or auto-dismiss after ~2.5s) — a
/// caller processing a queue of several simultaneous achievements
/// should `await` this before showing the next one, keeping them from
/// overlapping.
///
/// Custom AnimationController-based effect rather than a confetti
/// package: this project already avoids adding a dependency for a
/// small one-off effect when Flutter's own animation primitives cover
/// it (same call as skipping `intl` for a one-line date formatter
/// elsewhere in this codebase) — a badge pop plus a small radial
/// particle burst, both driven by one controller, is enough for
/// "celebratory" without pulling in a whole physics-based confetti
/// engine for something shown for ~2.5 seconds a few times a month.
Future<void> showTierCelebration(
  BuildContext context, {
  required Challenge challenge,
  required ChallengeTier tier,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, animation, secondaryAnimation) =>
        _TierCelebrationDialog(challenge: challenge, tier: tier),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
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
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
    _badgeScale = CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.elasticOut));
    _particles = _generateParticles(TierBadge.colorFor(widget.tier));

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  List<_Particle> _generateParticles(Color tierColor) {
    final random = Random();
    final colors = [tierColor, Colors.white, tierColor.withValues(alpha: 0.7)];
    return List.generate(18, (i) {
      final angle = (2 * pi / 18) * i + random.nextDouble() * 0.3;
      final distance = 60 + random.nextDouble() * 40;
      return _Particle(
        angle: angle,
        distance: distance,
        color: colors[i % colors.length],
        radius: 2.5 + random.nextDouble() * 2,
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
    final theme = Theme.of(context);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            width: 280,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, 8))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _ParticleBurstPainter(particles: _particles, progress: _controller.value),
                        child: Center(
                          child: Transform.scale(
                            scale: _badgeScale.value,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: TierBadgeIcon(tier: widget.tier, size: 72),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'New Tier Achieved!',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.tier.label} — ${widget.challenge.title}',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
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

/// Radial burst — each particle travels outward along its own [angle]
/// and fades out, driven entirely by [progress] (0.0 to 1.0), no
/// per-particle AnimationController.
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
    final opacity = progress <= fadeStart ? 1.0 : (1 - ((progress - fadeStart) / (1 - fadeStart))).clamp(0.0, 1.0);
    if (opacity <= 0) return;

    for (final particle in particles) {
      final offset = center +
          Offset(cos(particle.angle), sin(particle.angle)) * (particle.distance * travel);
      final paint = Paint()..color = particle.color.withValues(alpha: opacity);
      canvas.drawCircle(offset, particle.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticleBurstPainter oldDelegate) => oldDelegate.progress != progress;
}
