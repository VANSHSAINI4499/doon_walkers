import 'package:doon_walkers/core/theme/app_colors.dart';
import 'package:doon_walkers/core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// DoonWalkers typography — **Plus Jakarta Sans**, one family, everything.
///
/// ## Apple-style hierarchy
///
/// The direction asks for large hero numbers as the focal point, medium-
/// weight titles and short descriptions — "Today / 8,432 / steps" rather
/// than a sentence. The scale is built for exactly that shape:
///
///  - **Stat numerals** ([statXLarge] … [statSmall]) are the focal point.
///    Tight line height, tight tracking, so the number sits right on top
///    of its caption and reads as one object.
///  - **[statLabel]** is the caption under it: small, wide-tracked, dim.
///    The number carries the meaning; the label only names it.
///  - **Titles** are medium weight (w600), not bold. The old scale ran
///    w700–w800 across headings and titles, which is loud; pulling titles
///    back to w600 is most of what makes a screen read as calm.
///  - **Body** stays w400 at a 1.5 line height, because trek descriptions
///    and rules run long.
///
/// ## Colour: styles no longer carry ink
///
/// Every base style below is defined with `color: null`, so text
/// **inherits** its colour from the enclosing [DefaultTextStyle] — which
/// is to say, from the active theme. That is what lets an unmigrated
/// screen's `Text(style: AppTextStyles.titleMedium)` come out charcoal in
/// light mode and near-white in dark mode with no edit.
///
/// The three deliberately-dim styles ([bodySmall], [statLabel],
/// [overline]) are the exception: dimness is part of their meaning, so
/// they carry [AppColors.textSecondary], which is a mid grey chosen to
/// stay legible against both themes.
///
/// Use [secondary]/[disabled]/[tinted] to shift a style rather than
/// hand-rolling `copyWith(color:)`. Pass a [BuildContext] to those and
/// they resolve exact palette ink for the current theme; omit it and they
/// fall back to the dual-safe constants.
///
/// ## google_fonts note
///
/// Fonts are fetched from Google's CDN on first use and cached. Offline
/// (and in CI/widget tests) they fall back to the system font silently —
/// layout stays valid, only the face differs.
abstract final class AppTextStyles {
  AppTextStyles._();

  /// The single type family for the whole app. Swap this one function to
  /// change the entire system's face.
  ///
  /// [color] defaults to null so text inherits theme ink — see the class
  /// doc. Only the intentionally-dim styles pass a value.
  static TextStyle _font({
    required double fontSize,
    required FontWeight fontWeight,
    required double letterSpacing,
    double? height,
    Color? color,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    height: height,
    color: color,
  );

  // ── Display — hero headlines ──────────────────────────────────────
  // Pulled back from w800 to w700: at display sizes w800 in this face
  // reads as shouting, and the calm direction wants the *number* to be
  // the loudest thing on screen, not the headline.

  static TextStyle get displayLarge => _font(
    fontSize: 52,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.4,
    height: 1.08,
  );

  static TextStyle get displayMedium => _font(
    fontSize: 42,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.1,
    height: 1.1,
  );

  static TextStyle get displaySmall => _font(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    height: 1.12,
  );

  // ── Stat numerals — the focal point ───────────────────────────────
  // These stay heavy (w700) while everything around them lightened. That
  // widening gap is what makes the hero number pop without needing a
  // colour, a glow or a container to do it.

  /// The hero number on a stat card — 64sp.
  static TextStyle get statXLarge => _font(
    fontSize: 64,
    fontWeight: FontWeight.w700,
    letterSpacing: -2,
    height: 1,
  );

  /// A primary stat — 40sp.
  static TextStyle get statLarge => _font(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.2,
    height: 1,
  );

  /// A secondary stat in a row of several — 28sp.
  static TextStyle get statMedium => _font(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.7,
    height: 1,
  );

  /// An inline stat inside a card or list row — 20sp.
  static TextStyle get statSmall => _font(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1,
  );

  /// The small caption under a stat number. The number shouts, the label
  /// whispers — so this one keeps its dim ink.
  static TextStyle get statLabel => _font(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    height: 1.2,
    color: AppColors.textSecondary,
  );

  // ── Headline — section headings ───────────────────────────────────

  static TextStyle get headlineLarge => _font(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.2,
  );

  static TextStyle get headlineMedium => _font(
    fontSize: 26,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    height: 1.22,
  );

  static TextStyle get headlineSmall => _font(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.25,
  );

  // ── Title — card headings, list tiles, app bar ────────────────────
  // Medium weight, per the direction. This is the single biggest change
  // in the scale.

  static TextStyle get titleLarge => _font(
    fontSize: 21,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.28,
  );

  static TextStyle get titleMedium => _font(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.32,
  );

  static TextStyle get titleSmall => _font(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.35,
  );

  // ── Body — readable copy ──────────────────────────────────────────

  static TextStyle get bodyLarge => _font(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.55,
  );

  static TextStyle get bodyMedium => _font(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.5,
  );

  /// Supporting body copy. Dim by definition — see the class doc.
  static TextStyle get bodySmall => _font(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.15,
    height: 1.45,
    color: AppColors.textSecondary,
  );

  // ── Label — buttons, chips, overlines ─────────────────────────────

  static TextStyle get labelLarge => _font(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.2,
  );

  static TextStyle get labelMedium => _font(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    height: 1.2,
  );

  static TextStyle get labelSmall => _font(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    height: 1.2,
  );

  /// A wide-tracked uppercase eyebrow ("UPCOMING", "YOUR STREAK").
  /// Dim by definition.
  static TextStyle get overline => _font(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    height: 1.2,
    color: AppColors.textSecondary,
  );

  // ── Modifiers ─────────────────────────────────────────────────────
  // Each takes an optional context. With one, you get the exact ink for
  // the active theme; without one, the dual-safe constant. The optional
  // parameter is what let all ~150 existing call sites keep working
  // unchanged while migrated screens opt into precision.

  /// Recolour to the supporting-text ink.
  static TextStyle secondary(TextStyle style, [BuildContext? context]) =>
      style.copyWith(
        color: context == null
            ? AppColors.textSecondary
            : AppPalette.of(context).textSecondary,
      );

  /// Recolour to the disabled/placeholder ink.
  static TextStyle disabled(TextStyle style, [BuildContext? context]) =>
      style.copyWith(
        color: context == null
            ? AppColors.textDisabled
            : AppPalette.of(context).textDisabled,
      );

  /// Recolour to an arbitrary hue (e.g. a stat in Nature Green).
  static TextStyle tinted(TextStyle style, Color color) =>
      style.copyWith(color: color);

  /// Force the primary ink for [context]'s theme. Use when a style must
  /// be opaque about its colour rather than inheriting — e.g. inside a
  /// widget that sets its own [DefaultTextStyle].
  static TextStyle primary(TextStyle style, BuildContext context) =>
      style.copyWith(color: AppPalette.of(context).textPrimary);

  /// A complete Material 3 [TextTheme] built from the scale above.
  ///
  /// [ink] colours the styles that inherit; the intentionally-dim ones
  /// keep their own colour. `AppTheme` passes each palette's
  /// `textPrimary`, which is what makes bare `Text` widgets theme-aware.
  static TextTheme textTheme({Color? ink, Color? dimInk}) {
    TextStyle c(TextStyle s) => ink == null ? s : s.copyWith(color: ink);
    TextStyle d(TextStyle s) => dimInk == null ? s : s.copyWith(color: dimInk);
    return TextTheme(
      displayLarge: c(displayLarge),
      displayMedium: c(displayMedium),
      displaySmall: c(displaySmall),
      headlineLarge: c(headlineLarge),
      headlineMedium: c(headlineMedium),
      headlineSmall: c(headlineSmall),
      titleLarge: c(titleLarge),
      titleMedium: c(titleMedium),
      titleSmall: c(titleSmall),
      bodyLarge: c(bodyLarge),
      bodyMedium: c(bodyMedium),
      bodySmall: d(bodySmall),
      labelLarge: c(labelLarge),
      labelMedium: c(labelMedium),
      labelSmall: c(labelSmall),
    );
  }
}
