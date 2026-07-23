import 'package:doon_walkers/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// DoonWalkers typography — **Plus Jakarta Sans**, one family, everything.
///
/// ## Why Plus Jakarta Sans over Outfit
///
/// Both were on the table for Redesign Phase 1 and both are good display
/// faces. Plus Jakarta Sans won on three counts that matter for *this*
/// app:
///
///  1. **It survives small sizes.** DoonWalkers is not a dashboard of big
///     numbers — it's dense content: trek descriptions, things-to-carry
///     lists, registration forms, comment threads. Outfit is a wide,
///     geometric face with relatively closed apertures; at 11–13sp it
///     goes airy and loses word shape. Plus Jakarta Sans has a taller
///     x-height and open apertures and stays comfortable down to 11sp.
///  2. **One family instead of two.** The pre-redesign system paired
///     Outfit (headings) with Inter (body), which is a safe pairing but a
///     visibly borrowed one. Plus Jakarta Sans carries both roles, so the
///     whole scale shares one skeleton and the system reads as designed
///     rather than assembled.
///  3. **It still has a voice at display sizes.** The angled terminals
///     and slightly squared bowls at ExtraBold read modern and sporty at
///     40–64sp — which is exactly where the stat numerals live — without
///     the corporate neutrality of Inter or the novelty of a pure
///     geometric.
///
/// Outfit remains the fallback pick if the brand ever wants a harder,
/// more geometric display voice; swapping is a one-line change to
/// [_font].
///
/// ## Weight ladder
///
/// - Display / stat numerals: w800 (ExtraBold)
/// - Headings: w700 (Bold)
/// - Titles / buttons: w600 (SemiBold)
/// - Body: w400, secondary body: w400 at [AppColors.textSecondary]
///
/// Headings are bold on purpose and set tight (negative tracking); body
/// copy is set loose (positive tracking, 1.5 line height) so long trek
/// descriptions stay comfortable. That contrast — tight-and-loud versus
/// loose-and-calm — is most of the personality of this scale.
///
/// ## Colour
///
/// Styles here carry [AppColors.textPrimary] by default so a bare
/// `Text(...)` on a dark surface is legible even outside a themed
/// context. Use [secondary]/[disabled]/[tinted] to shift a style rather
/// than hand-rolling `copyWith(color:)` everywhere.
///
/// ## google_fonts note
///
/// Fonts are fetched from Google's CDN on first use and cached. Offline
/// (and in CI/widget tests) they fall back to the system font silently —
/// layout stays valid, only the face differs. To pin the face, bundle the
/// Plus Jakarta Sans .ttf files and swap [_font] for a plain
/// `TextStyle(fontFamily: ...)`.
abstract final class AppTextStyles {
  AppTextStyles._();

  /// The single type family for the whole app. Swap this one function to
  /// change the entire system's face.
  static TextStyle _font({
    required double fontSize,
    required FontWeight fontWeight,
    required double letterSpacing,
    double? height,
    Color color = AppColors.textPrimary,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    height: height,
    color: color,
  );

  // ── Display — hero headlines and big stat numerals ────────────────
  // Set at w800 with negative tracking: at these sizes default tracking
  // reads as gappy, and the whole point of a display size is density of
  // impact.

  static TextStyle get displayLarge =>
      _font(fontSize: 57, fontWeight: FontWeight.w800, letterSpacing: -1.5, height: 1.05);

  static TextStyle get displayMedium =>
      _font(fontSize: 45, fontWeight: FontWeight.w800, letterSpacing: -1.2, height: 1.08);

  static TextStyle get displaySmall =>
      _font(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -0.9, height: 1.1);

  // ── Stat numerals ─────────────────────────────────────────────────
  // Purpose-built for the "big number + small caption" pattern that runs
  // through Challenges, Profile streaks and Home community stats. These
  // are separate from the display scale because they need a *tight* line
  // height (the number should sit right on top of its caption) and
  // because a stat is a number, not a headline — pairing them by name
  // keeps later phases from reaching for displayLarge and getting a
  // 1.05 line box they then have to fight.

  /// The hero number on a stat card — 64sp.
  static TextStyle get statXLarge =>
      _font(fontSize: 64, fontWeight: FontWeight.w800, letterSpacing: -2, height: 1);

  /// A primary stat — 40sp.
  static TextStyle get statLarge =>
      _font(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1.4, height: 1);

  /// A secondary stat in a row of several — 28sp.
  static TextStyle get statMedium =>
      _font(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1);

  /// An inline stat inside a card or list row — 20sp.
  static TextStyle get statSmall =>
      _font(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4, height: 1);

  /// The small caption under a stat number. Uppercase, wide-tracked and
  /// dim — the number shouts, the label whispers.
  static TextStyle get statLabel => _font(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    height: 1.2,
    color: AppColors.textSecondary,
  );

  // ── Headline — section headings ───────────────────────────────────

  static TextStyle get headlineLarge =>
      _font(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.8, height: 1.15);

  static TextStyle get headlineMedium =>
      _font(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.6, height: 1.18);

  static TextStyle get headlineSmall =>
      _font(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.4, height: 1.2);

  // ── Title — card headings, list tiles, app bar ────────────────────

  static TextStyle get titleLarge =>
      _font(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3, height: 1.25);

  static TextStyle get titleMedium =>
      _font(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.1, height: 1.3);

  static TextStyle get titleSmall =>
      _font(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0, height: 1.35);

  // ── Body — readable copy ──────────────────────────────────────────
  // 1.5 line height and mildly positive tracking: these run long.

  static TextStyle get bodyLarge =>
      _font(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.1, height: 1.55);

  static TextStyle get bodyMedium =>
      _font(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.15, height: 1.5);

  static TextStyle get bodySmall => _font(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
    height: 1.45,
    color: AppColors.textSecondary,
  );

  // ── Label — buttons, chips, overlines ─────────────────────────────

  static TextStyle get labelLarge =>
      _font(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.1, height: 1.2);

  static TextStyle get labelMedium =>
      _font(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.2, height: 1.2);

  static TextStyle get labelSmall =>
      _font(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4, height: 1.2);

  /// A wide-tracked uppercase overline for section eyebrows
  /// ("UPCOMING", "YOUR STREAK").
  static TextStyle get overline => _font(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.6,
    height: 1.2,
    color: AppColors.textSecondary,
  );

  // ── Modifiers ─────────────────────────────────────────────────────

  /// Recolour to the supporting-text grey.
  static TextStyle secondary(TextStyle style) =>
      style.copyWith(color: AppColors.textSecondary);

  /// Recolour to the disabled/placeholder grey.
  static TextStyle disabled(TextStyle style) =>
      style.copyWith(color: AppColors.textDisabled);

  /// Recolour to an arbitrary brand hue (e.g. a stat in Electric Green).
  static TextStyle tinted(TextStyle style, Color color) =>
      style.copyWith(color: color);

  /// A complete Material 3 [TextTheme] built from the scale above.
  static TextTheme get textTheme => TextTheme(
    displayLarge: displayLarge,
    displayMedium: displayMedium,
    displaySmall: displaySmall,
    headlineLarge: headlineLarge,
    headlineMedium: headlineMedium,
    headlineSmall: headlineSmall,
    titleLarge: titleLarge,
    titleMedium: titleMedium,
    titleSmall: titleSmall,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
    labelLarge: labelLarge,
    labelMedium: labelMedium,
    labelSmall: labelSmall,
  );
}
