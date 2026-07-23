import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:flutter/material.dart';

/// Shared bronze/silver/gold/platinum visual treatment, reused across
/// every challenge (Version 2, Phase C2 — item 2) — one icon glyph,
/// tinted per tier, rather than distinct art per tier. Keeps this
/// maintainable as new challenges get added from the backend with zero
/// code changes: any [ChallengeTier] value already renders correctly
/// everywhere this is used.
abstract final class TierBadge {
  /// Gold reuses the app's own brand amber (AppColors.secondary) —
  /// deliberate, not a coincidence: it's the one tier color that
  /// already had an on-brand match. The other three are chosen to sit
  /// visually between/around it at a consistent saturation, not lifted
  /// from a generic "medal" palette.
  static Color colorFor(ChallengeTier tier) => switch (tier) {
    ChallengeTier.bronze => const Color(0xFFB08D57),
    ChallengeTier.silver => const Color(0xFF9AA6B2),
    ChallengeTier.gold => const Color(0xFFE9A84C),
    ChallengeTier.platinum => const Color(0xFF7C93AC),
  };

  /// Same glyph for every tier — [colorFor] is what actually
  /// differentiates them, so adding a 5th tier later never needs new
  /// icon art, only a new switch arm on [colorFor].
  static const IconData icon = Icons.military_tech_rounded;
}

/// A single tier badge — icon in a tinted circle, optional label
/// beneath it. [locked] renders the same badge desaturated (outline
/// icon, muted background) for tiers the user hasn't reached yet, used
/// on Challenge Detail's tier ladder.
class TierBadgeIcon extends StatelessWidget {
  const TierBadgeIcon({
    super.key,
    required this.tier,
    this.size = 40,
    this.locked = false,
  });

  final ChallengeTier tier;
  final double size;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = locked ? theme.colorScheme.outline : TierBadge.colorFor(tier);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: locked ? theme.colorScheme.surfaceContainerHighest : color.withValues(alpha: 0.16),
        border: locked ? Border.all(color: theme.colorScheme.outlineVariant) : null,
      ),
      child: Icon(
        locked ? Icons.lock_outline_rounded : TierBadge.icon,
        color: color,
        size: size * 0.52,
      ),
    );
  }
}
