import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// DoonWalkers typography system.
///
/// Display / heading:   Outfit — geometric, modern, adventurous.
/// Body / UI:           Inter  — highly legible, neutral, professional.
///
/// NOTE on google_fonts CDN: fonts are fetched from Google's CDN at
/// runtime on first use. In offline / CI environments they will silently
/// fall back to the system font. To pin bundled assets instead, download
/// the .ttf files and reference them via pubspec.yaml font declarations,
/// then replace these GoogleFonts.* calls with TextStyle(fontFamily: …).
abstract final class AppTextStyles {
  AppTextStyles._();

  // ── Display (Outfit) — hero headlines ────────────────────────────
  static TextStyle displayLarge = GoogleFonts.outfit(
    fontSize: 57,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
  );

  static TextStyle displayMedium = GoogleFonts.outfit(
    fontSize: 45,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  static TextStyle displaySmall = GoogleFonts.outfit(
    fontSize: 36,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  // ── Headline (Outfit) — section headings ─────────────────────────
  static TextStyle headlineLarge = GoogleFonts.outfit(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  static TextStyle headlineMedium = GoogleFonts.outfit(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  static TextStyle headlineSmall = GoogleFonts.outfit(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  // ── Title (Outfit) — card headings, list tiles ───────────────────
  static TextStyle titleLarge = GoogleFonts.outfit(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  static TextStyle titleMedium = GoogleFonts.outfit(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
  );

  static TextStyle titleSmall = GoogleFonts.outfit(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  // ── Body (Inter) — readable body copy ────────────────────────────
  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
  );

  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
  );

  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
  );

  // ── Label (Inter) — buttons, chips, overlines ────────────────────
  static TextStyle labelLarge = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  static TextStyle labelMedium = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static TextStyle labelSmall = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  /// Returns a complete Material 3 [TextTheme] built from the styles above.
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
