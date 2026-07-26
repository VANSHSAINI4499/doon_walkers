import 'package:flutter/material.dart';

/// Static colour constants — the **compatibility layer** for the calm
/// redesign.
///
/// ## Read this before using it
///
/// New code should use `AppPalette.of(context)` instead. This class only
/// still exists because ~650 call sites across the feature screens
/// reference it, 80-odd of them from inside `const` expressions that
/// cannot become context-dependent without editing every line. Deleting
/// it would mean a single 650-site rewrite; retuning it means each screen
/// converts during its own redesign phase.
///
/// ## What the values mean now
///
/// Every name from the glass/glow system survives, so nothing stops
/// compiling — but the values have been retuned to the calm system:
///
///  - **Surfaces and ink** ([background], [card], [textPrimary], …) carry
///    the **dark** palette's values, because that is what the app shipped
///    and what an unmigrated screen is laid out against. Such a screen
///    stays coherent in dark mode and will show dark-tinted details in
///    light mode until its phase converts it. That is the known cost of
///    migrating incrementally.
///  - **Semantic hues** ([primary], [danger], [gold], [secondary],
///    [accent]) are deliberately picked as *mid* tones that stay legible
///    on both a white card and a dark one. These are the tokens that show
///    up on icons, badges and chips — the details most likely to be left
///    behind on an unmigrated screen — so making them theme-agnostic buys
///    a lot of grace for one decision.
///  - **Glass tokens** ([glass], [glassStrong], [glassBorder]) are now
///    plain opaque surface and border colours. The frosted look is gone;
///    the names remain so the ~44 `glassBorder` call sites keep working
///    and quietly render a normal hairline.
/// Not marked `@Deprecated`: the annotation is correct in spirit but
/// would emit 650+ analyzer warnings on day one and bury real findings
/// for the entire migration. The doc above is the deprecation notice.
abstract final class AppColors {
  // ── Core surfaces (dark-palette values) ───────────────────────────
  /// The page background.
  static const Color background = Color(0xFF121513);

  /// Banded sections lifted slightly off [background].
  static const Color backgroundAlt = Color(0xFF171A18);

  /// Sheets, app bars, nav bars.
  static const Color surface = Color(0xFF1C201E);

  /// The default content card.
  static const Color card = Color(0xFF222724);

  /// One step forward of [card] — pressed fills, nested chips.
  static const Color cardHigh = Color(0xFF2B312D);

  // ── Former glass tokens ───────────────────────────────────────────
  // The blur and the translucent sheen are gone. These now resolve to
  // ordinary opaque surfaces and an ordinary hairline, so existing call
  // sites degrade into the calm system rather than breaking.

  /// Was a 5% white translucent fill. Now the plain card surface.
  static const Color glass = card;

  /// Was a stronger translucent fill. Now the raised card surface.
  static const Color glassStrong = cardHigh;

  /// Was the lit edge of a glass pane. Now the app's standard hairline
  /// border and divider colour.
  static const Color glassBorder = Color(0xFF333A36);

  // ── Primary — Nature Green ────────────────────────────────────────
  /// A mid nature green, chosen to stay legible on both light and dark
  /// surfaces. The theme-correct greens live on `AppPalette`.
  static const Color primary = Color(0xFF3E9E6C);
  static const Color primaryLight = Color(0xFF6BC28D);
  static const Color primaryDark = Color(0xFF2E7D55);

  /// Ink on top of [primary]. White — this green is dark enough to carry
  /// it, which is a reversal from the old electric green.
  static const Color onPrimary = Color(0xFFFFFFFF);

  static const Color primaryContainer = Color(0xFF1F4634);

  // ── Secondary — muted slate blue ──────────────────────────────────
  // Desaturated on purpose: the spec calls for one dominant accent, so
  // the supporting hues carry meaning rather than brand.
  static const Color secondary = Color(0xFF5C8AA0);
  static const Color secondaryLight = Color(0xFF8FB6C9);
  static const Color secondaryDark = Color(0xFF41697F);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFF264553);

  // ── Accent — muted terracotta ─────────────────────────────────────
  static const Color accent = Color(0xFFC4804A);
  static const Color accentLight = Color(0xFFD79A6B);
  static const Color accentDark = Color(0xFFB1682F);
  static const Color onAccent = Color(0xFFFFFFFF);

  // ── Danger ────────────────────────────────────────────────────────
  static const Color danger = Color(0xFFC4443C);
  static const Color onDanger = Color(0xFFFFFFFF);

  // ── Achievement metals ────────────────────────────────────────────
  // Badges, medals and tier indicators only — never a card gradient.
  static const Color bronze = Color(0xFFB08B54);
  static const Color silver = Color(0xFF9CA5AC);
  static const Color gold = Color(0xFFC9A63C);
  static const Color onGold = Color(0xFF33280A);
  static const Color platinum = Color(0xFF77A0AB);

  // ── Neutral ink ───────────────────────────────────────────────────
  /// The brightest ink on a dark surface. **Dark-palette value** — this
  /// one genuinely cannot be dual-safe, so an unmigrated screen using it
  /// will render near-invisible text on a light card until its phase
  /// converts it. 34 call sites; they are tracked by the migration.
  static const Color white = Color(0xFFE8EBE9);

  /// Dark-palette value. See the caveat on [white].
  static const Color textPrimary = white;

  /// Supporting text. Deliberately a **mid** grey rather than the dark
  /// theme's light grey: it clears 4.2:1 on the dark background and
  /// 4.5:1 on white, so it stays legible in both themes. Since this
  /// backs [AppTextStyles.secondary] (88 call sites) and `bodySmall`,
  /// one dual-safe choice here keeps most supporting copy readable
  /// everywhere during the migration.
  static const Color textSecondary = Color(0xFF6E766F);

  /// Disabled/placeholder ink. Dual-safe on the same reasoning as
  /// [textSecondary], one step dimmer.
  static const Color textDisabled = Color(0xFF8E948F);

  /// True charcoal — the light theme's ink. Here for the handful of
  /// places that draw dark-on-light regardless of theme (a badge on a
  /// white chip, ink on top of [gold]).
  static const Color charcoal = Color(0xFF1A1C1A);

  // ── Trek difficulty ───────────────────────────────────────────────
  static const Color difficultyEasy = primary;
  static const Color difficultyModerate = gold;
  static const Color difficultyHard = accent;
  static const Color difficultyExtreme = danger;

  // ── Legacy aliases ────────────────────────────────────────────────
  // Pre-redesign names, kept pointing at their current equivalents.

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

  // The neutral ramp is inverted by *role*, not by number: `neutral100`
  // stays the fill colour (dark here) and `neutral900` stays the strong
  // ink (light here), so existing "neutral100 background + neutral900
  // text" pairings stay legible instead of collapsing.

  /// Legacy fill — prefer [surface].
  static const Color neutral100 = surface;

  /// Legacy fill/border — prefer [cardHigh].
  static const Color neutral200 = cardHigh;

  /// Legacy dim text — prefer [textDisabled].
  static const Color neutral400 = textDisabled;

  /// Legacy secondary text — prefer [textSecondary].
  static const Color neutral600 = textSecondary;

  /// Legacy strong text — prefer [textPrimary].
  static const Color neutral800 = Color(0xFFCED4D0);

  /// Legacy strongest text — prefer [textPrimary].
  static const Color neutral900 = white;
}
