import 'package:doon_walkers/core/theme/app_colors.dart';
import 'package:flutter/widgets.dart';

/// Shadow and glow tokens.
///
/// On a near-black background a conventional grey drop shadow is
/// invisible, so depth here comes from two stacked effects:
///
///  1. a **deep shadow** — pure black, generously blurred, offset down.
///     It darkens the background beneath a surface so the surface reads
///     as lifted off the page.
///  2. a **coloured glow** — the element's own hue, blurred wide with no
///     offset. This is what makes a primary button or an active card
///     look like it is emitting light rather than sitting flat.
///
/// Nothing in this design system is flat: every floating surface gets at
/// least [soft].
abstract final class AppShadows {
  /// Barely-there lift, for chips and inline controls.
  static const List<BoxShadow> subtle = [
    BoxShadow(color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  /// The default card lift.
  static const List<BoxShadow> soft = [
    BoxShadow(color: Color(0x59000000), blurRadius: 24, offset: Offset(0, 10)),
  ];

  /// A hero/modal-level lift.
  static const List<BoxShadow> strong = [
    BoxShadow(color: Color(0x80000000), blurRadius: 40, offset: Offset(0, 18)),
  ];

  /// A coloured halo around an element, in [color].
  ///
  /// [opacity] is the alpha of the halo (0–1) and [radius] its blur.
  /// Pair it with [soft] or [strong] rather than using it alone — a glow
  /// with no dark shadow beneath reads as a smudge.
  static List<BoxShadow> glow(
    Color color, {
    double opacity = 0.35,
    double radius = 24,
    double spread = 0,
  }) => [
    BoxShadow(
      color: color.withValues(alpha: opacity),
      blurRadius: radius,
      spreadRadius: spread,
    ),
  ];

  /// The standard treatment for a floating, glowing surface: a deep
  /// shadow for lift plus a halo of [color] for emission.
  static List<BoxShadow> lifted(
    Color color, {
    double glowOpacity = 0.22,
    double glowRadius = 28,
  }) => [
    ...soft,
    BoxShadow(
      color: color.withValues(alpha: glowOpacity),
      blurRadius: glowRadius,
    ),
  ];

  /// What a [PremiumButton]-class control carries at rest.
  static List<BoxShadow> button(Color color) => [
    const BoxShadow(color: Color(0x4D000000), blurRadius: 16, offset: Offset(0, 8)),
    BoxShadow(color: color.withValues(alpha: 0.34), blurRadius: 22, offset: const Offset(0, 6)),
  ];

  /// The default glass-card treatment — a black lift plus a very faint
  /// white halo, which is what sells the "thin lit edge" of glass.
  static const List<BoxShadow> glass = [
    BoxShadow(color: Color(0x66000000), blurRadius: 28, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x0DFAFAFA), blurRadius: 20),
  ];

  /// Used by the theme's own defaults so `AppColors` stays the single
  /// source of the brand hue for glows.
  static List<BoxShadow> get primaryGlow => glow(AppColors.primary);
}
