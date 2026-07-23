import 'package:flutter/material.dart';

/// DoonWalkers colour palette — **dark-mode-first** (Redesign Phase 1).
///
/// The app ships a single dark theme. Every value here is fixed by the
/// Phase 1 design spec; do not invent new raw [Color] literals in feature
/// code — add a token here instead so the palette stays re-themeable.
///
/// ## Layering model
///
/// Depth is expressed by *surface elevation*, not by drop shadows:
///
/// ```
///   background   #090909   the page itself, behind everything
///   backgroundAlt#111111   secondary/banded background regions
///   surface      #181818   sheets, bars, non-floating containers
///   card         #202020   opaque cards and raised content
///   glass        5% white  translucent, blurred "floating" surfaces
/// ```
///
/// ## Legacy names
///
/// The pre-redesign light palette used names like [neutral100] and
/// [textPrimary]. Those names are all still here, remapped to their dark
/// equivalents, so the ~50 existing usages across the app keep compiling
/// and degrade gracefully while screens are migrated phase by phase. The
/// neutral ramp is **inverted by role, not by number**: `neutral100`/
/// `neutral200` remain the *fill* colours (now dark) and `neutral800`/
/// `neutral900` remain the *strong text* colours (now light), so existing
/// "neutral100 background + neutral900 text" pairings stay legible instead
/// of collapsing into dark-on-dark.
abstract final class AppColors {
  // ── Core surfaces ─────────────────────────────────────────────────
  /// The page background — the darkest surface in the system.
  static const Color background = Color(0xFF090909);

  /// Secondary background, for banded sections that must read as
  /// *slightly* lifted off [background] without becoming a card.
  static const Color backgroundAlt = Color(0xFF111111);

  /// Sheets, app bars, nav bars, and other non-floating containers.
  static const Color surface = Color(0xFF181818);

  /// Opaque cards and raised content blocks.
  static const Color card = Color(0xFF202020);

  /// One step above [card] — hover/pressed fills, nested chips on cards.
  static const Color cardHigh = Color(0xFF262626);

  // ── Glass ─────────────────────────────────────────────────────────
  /// Fill for translucent, blurred "floating" surfaces (see `GlassCard`).
  /// 5% white over whatever is behind it.
  static const Color glass = Color(0x0DFFFFFF);

  /// A slightly stronger glass fill, for the top edge of a glass gradient
  /// or for pressed states on glass.
  static const Color glassStrong = Color(0x1AFFFFFF);

  /// The thin hairline border that gives glass surfaces their edge.
  /// Also the app-wide divider colour. 8% white.
  static const Color glassBorder = Color(0x14FFFFFF);

  // ── Primary — Electric Green ──────────────────────────────────────
  static const Color primary = Color(0xFF4ADE80);
  static const Color primaryLight = Color(0xFF86EFAC);
  static const Color primaryDark = Color(0xFF22C55E);

  /// Content drawn *on top of* [primary]. Electric green is a light
  /// colour — content on it must be near-black ink, never white.
  static const Color onPrimary = Color(0xFF052E16);

  /// A dim, desaturated green for filled chips/containers that carry
  /// primary meaning without shouting.
  static const Color primaryContainer = Color(0xFF14532D);

  // ── Secondary — Sky Blue ──────────────────────────────────────────
  static const Color secondary = Color(0xFF38BDF8);
  static const Color secondaryLight = Color(0xFF7DD3FC);
  static const Color secondaryDark = Color(0xFF0284C7);
  static const Color onSecondary = Color(0xFF042F3F);
  static const Color secondaryContainer = Color(0xFF075985);

  // ── Accent — Orange ───────────────────────────────────────────────
  static const Color accent = Color(0xFFFB923C);
  static const Color accentLight = Color(0xFFFDBA74);
  static const Color accentDark = Color(0xFFEA7317);
  static const Color onAccent = Color(0xFF3A1A05);

  // ── Danger ────────────────────────────────────────────────────────
  static const Color danger = Color(0xFFEF4444);
  static const Color onDanger = Color(0xFFFFFFFF);

  // ── Gold — achievements, badges, ratings ──────────────────────────
  static const Color gold = Color(0xFFFFD54F);
  static const Color onGold = Color(0xFF3A2C00);

  // ── Neutral text ramp ─────────────────────────────────────────────
  /// The app's brightest ink. Deliberately #FAFAFA rather than pure
  /// white — pure white on a near-black background haloes on OLED.
  static const Color white = Color(0xFFFAFAFA);

  /// Primary body/heading text.
  static const Color textPrimary = white;

  /// Supporting text, captions, metadata. ~7:1 on [background].
  static const Color textSecondary = Color(0xFFA1A1A1);

  /// Disabled/placeholder text. ~3.4:1 on [background] — legible enough
  /// to read, dim enough to read as unavailable.
  static const Color textDisabled = Color(0xFF6E6E6E);

  // ── Trek difficulty scale ─────────────────────────────────────────
  // Mapped onto the redesign palette rather than kept as bespoke hues,
  // so difficulty badges sit inside the same colour system as everything
  // else: green → gold → orange → red is already the accent progression.
  static const Color difficultyEasy = primary;
  static const Color difficultyModerate = gold;
  static const Color difficultyHard = accent;
  static const Color difficultyExtreme = danger;

  // ── Legacy aliases ────────────────────────────────────────────────
  // Kept so pre-redesign screens keep compiling and stay readable until
  // their own phase migrates them. Prefer the semantic names above in
  // all new code.

  /// Legacy alias — prefer [card].
  static const Color surfaceVariant = card;

  /// Legacy alias — prefer [textPrimary].
  static const Color onBackground = textPrimary;

  /// Legacy alias — prefer [textPrimary].
  static const Color onSurface = textPrimary;

  /// Legacy alias — prefer [danger].
  static const Color error = danger;

  /// Legacy alias — prefer [onDanger].
  static const Color onError = onDanger;

  /// Legacy alias — prefer [glassBorder].
  static const Color divider = glassBorder;

  // Inverted-by-role neutral ramp (see this class's doc).
  /// Legacy fill — prefer [surface].
  static const Color neutral100 = surface;

  /// Legacy fill/border — prefer [cardHigh].
  static const Color neutral200 = cardHigh;

  /// Legacy dim text — prefer [textDisabled].
  static const Color neutral400 = textDisabled;

  /// Legacy secondary text — prefer [textSecondary].
  static const Color neutral600 = textSecondary;

  /// Legacy strong text — prefer [textPrimary].
  static const Color neutral800 = Color(0xFFD4D4D4);

  /// Legacy strongest text — prefer [textPrimary].
  static const Color neutral900 = white;
}
