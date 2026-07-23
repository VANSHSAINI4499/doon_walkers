import 'package:flutter/widgets.dart';

/// The app's spacing scale.
///
/// A 4dp base grid. Screens should compose padding and gaps out of these
/// steps rather than arbitrary numbers — that's what makes unrelated
/// screens feel like one product.
abstract final class AppSpacing {
  /// 4 — hairline gaps, icon-to-label inside a dense chip.
  static const double xs = 4;

  /// 8 — tight internal gaps.
  static const double sm = 8;

  /// 12 — icon-to-label in buttons, chip padding.
  static const double md = 12;

  /// 16 — the default screen gutter and card padding.
  static const double lg = 16;

  /// 20 — roomy card padding.
  static const double xl = 20;

  /// 24 — gap between distinct content blocks.
  static const double xxl = 24;

  /// 32 — gap between sections.
  static const double xxxl = 32;

  /// 48 — top/bottom breathing room on hero areas and empty states.
  static const double huge = 48;

  /// The standard horizontal screen gutter.
  static const double screenGutter = lg;

  /// Vertical gap between stacked cards in a list.
  static const double cardGap = md;
}

/// The app's corner-radius scale.
///
/// The redesign is built on large, soft radii — nothing in the system is
/// square, and cards read as *floating pills of content* rather than
/// boxes. [card] is the 24–28dp band the Phase 1 spec calls for.
abstract final class AppRadius {
  /// 8 — the smallest radius in the system (tiny badges, inline tags).
  static const double xs = 8;

  /// 12 — inputs, small chips.
  static const double sm = 12;

  /// 18 — buttons. The Phase 1 floor for a [PremiumButton]-class control.
  static const double button = 18;

  /// 20 — the default button radius (button floor + one step of softness).
  static const double md = 20;

  /// 24 — the lower bound of the glass-card band.
  static const double card = 24;

  /// 28 — the upper bound of the glass-card band; hero cards, sheets.
  static const double lg = 28;

  /// 36 — full-bleed sheet tops and oversized feature cards.
  static const double xl = 36;

  /// Effectively a pill/stadium shape.
  static const double pill = 999;

  static BorderRadius all(double r) => BorderRadius.circular(r);

  /// Rounds only the top corners — bottom sheets, sticky headers.
  static BorderRadius top(double r) => BorderRadius.vertical(top: Radius.circular(r));
}

/// Blur radii for translucent surfaces.
///
/// Kept as tokens because blur sigma is a performance knob as much as a
/// visual one: a stronger blur costs more per frame, so long lists should
/// stay at [subtle] or disable blur entirely.
abstract final class AppBlur {
  /// 8 — cheap; safe inside scrolling lists.
  static const double subtle = 8;

  /// 18 — the default glass look.
  static const double standard = 18;

  /// 30 — heavy frost, for modal scrims and hero overlays only.
  static const double heavy = 30;
}
