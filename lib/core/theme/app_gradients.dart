import 'package:doon_walkers/core/theme/app_colors.dart';
import 'package:flutter/widgets.dart';

/// Gradient tokens.
///
/// Flat fills are the exception in this design system, not the rule:
/// buttons, badges and glass surfaces all carry a subtle top-left →
/// bottom-right gradient so they catch light like a physical object.
///
/// All directional gradients run [Alignment.topLeft] →
/// [Alignment.bottomRight] so multiple elements on one screen appear lit
/// from the same direction.
abstract final class AppGradients {
  static const Alignment _from = Alignment.topLeft;
  static const Alignment _to = Alignment.bottomRight;

  /// Electric green — the primary call to action.
  static const LinearGradient primary = LinearGradient(
    begin: _from,
    end: _to,
    colors: [AppColors.primaryLight, AppColors.primaryDark],
  );

  /// Sky blue — secondary actions.
  static const LinearGradient secondary = LinearGradient(
    begin: _from,
    end: _to,
    colors: [AppColors.secondaryLight, AppColors.secondaryDark],
  );

  /// Orange — accent actions, "in progress"/streak surfaces.
  static const LinearGradient accent = LinearGradient(
    begin: _from,
    end: _to,
    colors: [AppColors.accentLight, AppColors.accentDark],
  );

  /// Red — destructive actions.
  static const LinearGradient danger = LinearGradient(
    begin: _from,
    end: _to,
    colors: [Color(0xFFF87171), Color(0xFFDC2626)],
  );

  /// Gold — achievements, badges, top-of-leaderboard surfaces.
  static const LinearGradient gold = LinearGradient(
    begin: _from,
    end: _to,
    colors: [Color(0xFFFFE082), Color(0xFFF0B429)],
  );

  /// The sheen that sits *inside* a glass surface: brighter at the top
  /// edge, fading to near-nothing at the bottom. This is what stops a
  /// translucent panel from reading as a flat grey rectangle.
  static const LinearGradient glassSheen = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.glassStrong, AppColors.glass],
  );

  /// A neutral raised-card fill for opaque (non-blurred) cards.
  static const LinearGradient cardFill = LinearGradient(
    begin: _from,
    end: _to,
    colors: [AppColors.cardHigh, AppColors.card],
  );

  /// Bottom-up scrim for text laid over a photograph. Trek cover images
  /// are the main consumer; kept here so every image overlay in the app
  /// uses the same falloff.
  static const LinearGradient imageScrim = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [Color(0xE6090909), Color(0x99090909), Color(0x00090909)],
    stops: [0, 0.45, 1],
  );

  /// A disabled control: no hue, no light direction, just dead surface.
  static const LinearGradient disabled = LinearGradient(
    begin: _from,
    end: _to,
    colors: [AppColors.cardHigh, AppColors.card],
  );
}
