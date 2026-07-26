import 'package:doon_walkers/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

/// Elevation tokens — **soft, neutral, close to the surface**.
///
/// This replaces the glow model wholesale. The old system expressed depth
/// as a deep black drop plus a coloured halo, so every card looked like it
/// was emitting light. The calm system expresses depth the way physical
/// paper does: a small, low-opacity, slightly-offset shadow that you feel
/// rather than see.
///
/// Three levels, and that is the whole ladder:
///
/// ```
///   level1   resting cards, chips             y1  blur 3
///   level2   raised/pressed cards, buttons    y2  blur 8
///   level3   sheets, dialogs, floating bars   y6  blur 20
/// ```
///
/// Most surfaces should use [level1] or nothing at all. If a screen needs
/// three different elevations to be readable, the problem is the layout,
/// not the shadow.
///
/// ## Theme-aware vs. const
///
/// [of] takes a palette and returns shadows tuned for that theme — dark
/// themes need more opacity to register at all. The `static const` lists
/// below are the **light-theme** values, kept because ~20 files reference
/// `AppShadows.soft`/`.subtle`/`.strong` directly from `const` contexts.
/// Prefer [of] in new code.
abstract final class AppShadows {
  // ── Theme-aware (preferred) ───────────────────────────────────────

  /// Elevation [level] (1–3) tuned for [palette]'s brightness.
  static List<BoxShadow> of(AppPalette palette, {int level = 1}) {
    final dark = palette.brightness == Brightness.dark;
    final shadow = palette.shadowColor;
    return switch (level) {
      <= 0 => const [],
      1 => [
        BoxShadow(
          color: shadow.withValues(alpha: dark ? 0.30 : 0.05),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ],
      2 => [
        BoxShadow(
          color: shadow.withValues(alpha: dark ? 0.36 : 0.07),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
      _ => [
        BoxShadow(
          color: shadow.withValues(alpha: dark ? 0.44 : 0.10),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
    };
  }

  // ── Const ladder (light-theme values) ─────────────────────────────

  /// Level 1 — the resting card. Barely there, on purpose.
  static const List<BoxShadow> subtle = [
    BoxShadow(color: Color(0x0D1A1C1A), blurRadius: 3, offset: Offset(0, 1)),
  ];

  /// Level 2 — a raised card or a filled button.
  static const List<BoxShadow> soft = [
    BoxShadow(color: Color(0x121A1C1A), blurRadius: 8, offset: Offset(0, 2)),
  ];

  /// Level 3 — sheets, dialogs, the floating nav bar.
  static const List<BoxShadow> strong = [
    BoxShadow(color: Color(0x1A1A1C1A), blurRadius: 20, offset: Offset(0, 6)),
  ];

  /// Legacy name for the default card treatment — now identical to
  /// [subtle]. Kept so existing call sites keep compiling; there is no
  /// glass in this system.
  static const List<BoxShadow> glass = subtle;

  // ── Retired glow API ──────────────────────────────────────────────
  // These used to return coloured halos. They now return plain neutral
  // elevation and **ignore the colour argument entirely**. That is what
  // removes glow from the ~20 files that call them without those files
  // having to change. When a screen reaches its redesign phase, drop the
  // call and use `AppShadows.of(palette)`.

  /// Retired. Returns neutral [subtle]; [color] is ignored.
  static List<BoxShadow> glow(
    Color color, {
    double opacity = 0.35,
    double radius = 24,
    double spread = 0,
  }) => subtle;

  /// Retired. Returns neutral [soft]; [color] is ignored.
  static List<BoxShadow> lifted(
    Color color, {
    double glowOpacity = 0.22,
    double glowRadius = 28,
  }) => soft;

  /// Retired. Returns neutral [soft]; [color] is ignored.
  static List<BoxShadow> button(Color color) => soft;

  /// Retired. Returns neutral [subtle].
  static List<BoxShadow> get primaryGlow => subtle;
}
