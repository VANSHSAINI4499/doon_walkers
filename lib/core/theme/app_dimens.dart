import 'package:flutter/widgets.dart';

/// The app's spacing scale — an **8dp grid**, with 4 and 12 as the two
/// permitted half-steps.
///
/// The calm redesign leans on whitespace to create hierarchy instead of
/// on borders, glows and colour. That only works if the gaps are large
/// *and* consistent, so compose padding out of these steps and never out
/// of arbitrary numbers.
///
/// ## Values changed in the calm redesign
///
/// [xl] and above were all widened (20→24, 24→32, 32→40, 48→56) to put
/// the ladder on a true 8dp grid and to deliver the "generous padding,
/// large margins" the direction calls for. Every screen therefore gets
/// roomier the moment this lands, before its own phase touches it. That
/// is intended: it is the single cheapest change that makes the whole app
/// feel calmer.
abstract final class AppSpacing {
  /// 4 — half-step. Hairline gaps, icon-to-label inside a dense chip.
  static const double xs = 4;

  /// 8 — the grid unit. Tight internal gaps.
  static const double sm = 8;

  /// 12 — half-step. Icon-to-label in buttons, chip padding.
  static const double md = 12;

  /// 16 — the default screen gutter.
  static const double lg = 16;

  /// 24 — the default card padding. Generous by design.
  static const double xl = 24;

  /// 32 — gap between distinct content blocks.
  static const double xxl = 32;

  /// 40 — gap between sections.
  static const double xxxl = 40;

  /// 56 — top/bottom breathing room on hero areas and empty states.
  static const double huge = 56;

  /// The standard horizontal screen gutter.
  static const double screenGutter = lg;

  /// Vertical gap between stacked cards in a list.
  static const double cardGap = md;
}

/// The app's corner-radius scale.
///
/// The direction calls for a soft **16–24dp** band, which is where every
/// card, button and sheet in the system now sits. The old scale ran
/// 18–36dp and made cards read as floating pills; these are recognisably
/// rectangles with soft corners, which is calmer and lets content sit
/// closer to the edge.
abstract final class AppRadius {
  /// 8 — the smallest radius in the system (tiny badges, inline tags).
  static const double xs = 8;

  /// 12 — inputs, small chips.
  static const double sm = 12;

  /// 16 — buttons. The floor of the band.
  static const double button = 16;

  /// 16 — the default control radius.
  static const double md = 16;

  /// 20 — the default card.
  static const double card = 20;

  /// 24 — the ceiling of the band; hero cards, dialogs, sheets.
  static const double lg = 24;

  /// 28 — full-bleed sheet tops, where the corner meets a screen edge
  /// and needs to read as soft at a larger scale.
  static const double xl = 28;

  /// Effectively a pill/stadium shape.
  static const double pill = 999;

  static BorderRadius all(double r) => BorderRadius.circular(r);

  /// Rounds only the top corners — bottom sheets, sticky headers.
  static BorderRadius top(double r) =>
      BorderRadius.vertical(top: Radius.circular(r));
}

/// Backdrop-blur radii — **retired**.
///
/// The calm system has no frosted surfaces: depth comes from a flat fill,
/// a hairline border and a soft shadow. These constants remain only so
/// that call sites still passing `blur:` to a card keep compiling. Nothing
/// reads them any more.
abstract final class AppBlur {
  /// Retired. Unused.
  static const double subtle = 8;

  /// Retired. Unused.
  static const double standard = 18;

  /// Retired. Unused.
  static const double heavy = 30;
}
