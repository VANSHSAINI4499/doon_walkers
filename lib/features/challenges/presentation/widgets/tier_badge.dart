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

  /// A top-left→bottom-right gradient in the tier's colour, for filled
  /// badge surfaces that should catch light like the rest of the system.
  static LinearGradient gradientFor(ChallengeTier tier) {
    final base = colorFor(tier);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color.lerp(base, Colors.white, 0.35)!, base],
    );
  }

  /// Same glyph for every tier — [colorFor] is what differentiates them,
  /// so adding a 5th tier later needs only a new switch arm on [colorFor].
  static const IconData icon = AppIcons.medal;
}

/// A single tier badge — a medal glyph in a tinted, softly-glowing circle.
///
/// [locked] renders the same badge desaturated (a lock glyph over a muted
/// fill) for tiers the user hasn't reached yet, used on Challenge Detail's
/// tier ladder. [glow] adds a coloured halo for hero contexts (the
/// celebration, a card's current tier); it's off by default so a dense
/// list of badges doesn't shimmer.
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
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final color = TierBadge.colorFor(tier);

    if (locked) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.cardHigh,
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: AppIcon(AppIcons.lock, color: AppColors.textDisabled, size: size * 0.5),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: TierBadge.gradientFor(tier),
        boxShadow: glow ? AppShadows.glow(color, opacity: 0.5, radius: size * 0.5) : null,
      ),
      child: AppIcon(TierBadge.icon, color: AppColors.background, size: size * 0.52),
    );
  }
}
