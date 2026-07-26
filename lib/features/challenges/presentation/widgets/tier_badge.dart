import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:flutter/material.dart';

/// Shared bronze/silver/gold/platinum visual treatment, reused across
/// every challenge — one medal glyph, tinted per tier, rather than
/// distinct art per tier. Any [ChallengeTier] value renders correctly
/// everywhere this is used, so new challenges from the backend need zero
/// code changes.
///
/// ## Tier colour mapping
///
/// All four tiers now come straight off the design system's achievement
/// metal ramp — the one place the calm direction sanctions metallics at
/// all ("Bronze/Silver/Gold only for achievement badges/medals, never as
/// general card gradients"). Tier badges are exactly that case.
///
///  - **Bronze** → [AppColors.bronze]
///  - **Silver** → [AppColors.silver]
///  - **Gold** → [AppColors.gold]
///  - **Platinum** → [AppColors.platinum]
///
/// This replaces a half-migrated mapping where gold and platinum pointed
/// at brand tokens (the app's gold and Sky Blue) while bronze and silver
/// were hardcoded hexes — so retuning the palette moved two tiers and
/// left the other two behind. The ordering still reads at a glance
/// (bronze < silver < gold < platinum) and the *which tier* logic is
/// untouched.
///
/// These are still the theme-agnostic constants rather than
/// `AppPalette.of(context).bronze`; switching to the context-resolved
/// metals is Challenges-phase work, along with this widget's remaining
/// glow and gradient treatment.
abstract final class TierBadge {
  static Color colorFor(ChallengeTier tier) => switch (tier) {
    ChallengeTier.bronze => AppColors.bronze,
    ChallengeTier.silver => AppColors.silver,
    ChallengeTier.gold => AppColors.gold,
    ChallengeTier.platinum => AppColors.platinum,
  };

  /// Same glyph for every tier — [colorFor] is what differentiates them,
  /// so adding a 5th tier later needs only a new switch arm on [colorFor].
  static const IconData icon = AppIcons.medal;
}

/// A single tier badge — a medal glyph on a flat, tinted disc.
///
/// [locked] renders the same badge muted (a lock glyph on a dead fill) for
/// tiers the user hasn't reached yet, used on Challenge Detail's tier
/// ladder.
///
/// Redesign 2.0 Phase 12 flattened this: the metal gradient and the
/// coloured halo are gone. A tier is now a solid disc in its metal
/// colour, which is legible at 20px in a dense list and does not need a
/// glow to read as special — the metals are already the only saturated
/// colours the calm palette allows outside the single green accent.
///
/// The [glow] parameter survives so the ~4 call sites that pass it keep
/// compiling; it is ignored.
class TierBadgeIcon extends StatelessWidget {
  const TierBadgeIcon({
    super.key,
    required this.tier,
    this.size = 40,
    this.locked = false,
    this.glow = false,
  });

  final ChallengeTier tier;
  final double size;
  final bool locked;

  /// Retired — ignored. Was a coloured halo.
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    if (locked) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: palette.cardHigh,
          border: Border.all(color: palette.border),
        ),
        child: AppIcon(
          AppIcons.lock,
          color: palette.textDisabled,
          size: size * 0.46,
        ),
      );
    }

    final color = TierBadge.colorFor(tier);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: AppIcon(
        TierBadge.icon,
        // Ink sits on the metal disc, not on the page, so it does not
        // follow the theme: all four metals are mid-tone (bronze #B08B54
        // through platinum #77A0AB), where charcoal clears 4.5:1 and
        // white does not. One fixed dark ink is correct in both themes.
        color: AppColors.charcoal,
        size: size * 0.52,
      ),
    );
  }
}
