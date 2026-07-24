import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:flutter/material.dart';

/// Shared bronze/silver/gold/platinum visual treatment, reused across
/// every challenge — one medal glyph, tinted per tier, rather than
/// distinct art per tier. Any [ChallengeTier] value renders correctly
/// everywhere this is used, so new challenges from the backend need zero
/// code changes.
///
/// ## Redesign Phase 4 tier colour mapping (flagged per the brief)
///
/// The tiers keep recognisable medal *ordering* (so bronze < silver <
/// gold < platinum still reads at a glance) but are pulled onto the
/// Phase 1 palette, with the top two tiers tied to brand tokens:
///
///  - **Bronze** → warm copper `#C87941`
///  - **Silver** → cool silver `#B8C2CC`
///  - **Gold** → [AppColors.gold] (`#FFD54F`) — the app's own gold
///  - **Platinum** → [AppColors.secondary] (Sky Blue `#38BDF8`) — a cool,
///    premium top tier that glows differently from gold so "maxed out"
///    reads instantly
///
/// This replaces the pre-redesign values (bronze `#B08D57`, silver
/// `#9AA6B2`, gold `#E9A84C`, platinum `#7C93AC`). The *which tier* logic
/// is untouched — only the colours changed.
abstract final class TierBadge {
  static Color colorFor(ChallengeTier tier) => switch (tier) {
    ChallengeTier.bronze => const Color(0xFFC87941),
    ChallengeTier.silver => const Color(0xFFB8C2CC),
    ChallengeTier.gold => AppColors.gold,
    ChallengeTier.platinum => AppColors.secondary,
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
