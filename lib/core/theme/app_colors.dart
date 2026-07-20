import 'package:flutter/material.dart';

/// DoonWalkers brand colour palette.
///
/// Designed around a premium outdoor-adventure direction:
///   Primary   — Forest Green:  communicates nature, trails, sustainability.
///   Secondary — Amber/Gold:    warmth of campfires, sunrise on peaks.
///   Neutral   — Slate-grey:    modern minimal backgrounds and surfaces.
///   Error     — Deep Crimson:  standard Material error colour.
///
/// All values are constant; use [AppColors] everywhere instead of
/// raw [Color] literals so the palette is easily re-themed.
abstract final class AppColors {
  // ── Primary — Forest Green ────────────────────────────────────────
  static const Color primary = Color(0xFF2D6A4F);
  static const Color primaryLight = Color(0xFF52B788);
  static const Color primaryDark = Color(0xFF1B4332);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // ── Secondary — Amber / Warm Gold ────────────────────────────────
  static const Color secondary = Color(0xFFE9A84C);
  static const Color secondaryLight = Color(0xFFF4C87A);
  static const Color secondaryDark = Color(0xFFB07730);
  static const Color onSecondary = Color(0xFF1A1A1A);

  // ── Surface / Background ─────────────────────────────────────────
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFEDF2EE); // subtle green tint
  static const Color onBackground = Color(0xFF1A1A1A);
  static const Color onSurface = Color(0xFF1A1A1A);

  // ── Neutral Slate ─────────────────────────────────────────────────
  static const Color neutral100 = Color(0xFFF1F3F5);
  static const Color neutral200 = Color(0xFFDEE2E6);
  static const Color neutral400 = Color(0xFFADB5BD);
  static const Color neutral600 = Color(0xFF6C757D);
  static const Color neutral800 = Color(0xFF343A40);
  static const Color neutral900 = Color(0xFF212529);

  // ── Error ─────────────────────────────────────────────────────────
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);

  // ── Trek difficulty scale (Phase 4) ─────────────────────────────────
  static const Color difficultyEasy = Color(0xFF2D8A4E);
  static const Color difficultyModerate = Color(0xFFCB8A17);
  static const Color difficultyHard = Color(0xFFD9622B);
  static const Color difficultyExtreme = error;

  // ── Semantic shortcuts ────────────────────────────────────────────
  static const Color divider = neutral200;
  static const Color textPrimary = neutral900;
  static const Color textSecondary = neutral600;
  static const Color textDisabled = neutral400;
}
