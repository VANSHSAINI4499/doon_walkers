import 'package:flutter/animation.dart';

/// Motion tokens — the durations and curves every animation in the app
/// draws from.
///
/// The redesign's motion is **bold but short**: things move a lot, fast,
/// and settle with a slight overshoot rather than easing to a dead stop.
/// The way to keep that from becoming noise is to have very few
/// durations, used consistently, so simultaneous animations across a
/// screen land together instead of smearing.
///
/// Rules of thumb:
///  - Anything the finger is directly driving (press, toggle) → [instant]
///    or [fast]. Latency is felt above ~150ms.
///  - Anything the eye follows across the screen (a card expanding, a
///    sheet arriving) → [medium].
///  - Page transitions → [page].
///  - Ambient/looping effects (shimmer, pulse) → [shimmer] / [pulse].
///    These are long on purpose; a fast loop reads as a glitch.
abstract final class AppMotion {
  // ── Durations ─────────────────────────────────────────────────────

  /// 90ms — press feedback. Below the threshold where a tap feels laggy.
  static const Duration instant = Duration(milliseconds: 90);

  /// 160ms — hover/selection state changes, small colour fades.
  static const Duration fast = Duration(milliseconds: 160);

  /// 260ms — the workhorse. Container resizes, expand/collapse, list
  /// item entrance.
  static const Duration medium = Duration(milliseconds: 260);

  /// 400ms — larger movements: sheets, hero flights, cross-screen morphs.
  static const Duration slow = Duration(milliseconds: 400);

  /// 320ms — page-to-page route transitions.
  static const Duration page = Duration(milliseconds: 320);

  /// 1400ms — one full shimmer sweep across a skeleton.
  static const Duration shimmer = Duration(milliseconds: 1400);

  /// 1800ms — one breath of an ambient pulse/glow.
  static const Duration pulse = Duration(milliseconds: 1800);

  /// 60ms — the delay step between consecutive items in a staggered
  /// entrance. Small: 10 items should finish arriving well under a
  /// second.
  static const Duration staggerStep = Duration(milliseconds: 60);

  // ── Curves ────────────────────────────────────────────────────────

  /// The default curve for anything entering or moving. Material 3's
  /// "emphasized decelerate" shape — leaves fast, arrives gently.
  static const Curve emphasized = Cubic(0.05, 0.7, 0.1, 1);

  /// Symmetric ease, for state changes that aren't really "arrivals"
  /// (colour fades, opacity swaps).
  static const Curve standard = Cubic(0.2, 0, 0, 1);

  /// For things leaving the screen — accelerate away, no soft landing.
  static const Curve exit = Cubic(0.3, 0, 1, 1);

  /// A springy overshoot. This is the redesign's signature: use it for
  /// press-release, badge pops and anything that should feel physical.
  /// Do not use it on large surfaces — an overshooting full-screen sheet
  /// looks broken, not lively.
  static const Curve spring = Curves.easeOutBack;

  /// The gentle in-out used by looping ambient animations.
  static const Curve ambient = Curves.easeInOut;

  // ── Interaction constants ─────────────────────────────────────────

  /// How far a control shrinks while pressed. 4% is enough to read as a
  /// physical push without the label visibly reflowing.
  static const double pressScale = 0.96;

  /// A stronger press for large tappable surfaces (whole cards), where
  /// 4% would be barely perceptible across the bigger area.
  static const double pressScaleLarge = 0.98;

  /// The vertical distance an entering element travels in a fade-and-rise.
  static const double enterOffsetY = 24;
}
