import 'package:doon_walkers/core/theme/app_colors.dart';
import 'package:flutter/widgets.dart';

/// Gradient tokens — **almost none left, on purpose**.
///
/// The old system used a lit top-left → bottom-right gradient on every
/// button, badge and card so surfaces "caught light like a physical
/// object". Applied everywhere, that reads as decoration rather than
/// design, and it is most of what made the app look generated.
///
/// The calm system uses flat fills. These tokens survive because ~20
/// files reference them, but the colour gradients are now **flat** —
/// both stops are the same colour — so a call site that paints
/// `AppGradients.primary` gets a clean solid primary fill and needs no
/// edit. Only [imageScrim] remains a real gradient, because legibility
/// of text over a photograph genuinely requires one.
///
/// New code should not reach for this class at all. Use a solid colour
/// from `AppPalette`.
abstract final class AppGradients {
  /// A gradient between one colour and itself — i.e. a flat fill wearing
  /// a [Gradient]'s clothes, so existing `gradient:` parameters keep
  /// working without becoming `color:` edits.
  static LinearGradient _flat(Color color) =>
      LinearGradient(colors: [color, color]);

  /// Nature Green. Flat.
  static LinearGradient get primary => _flat(AppColors.primary);

  /// Muted slate blue. Flat.
  static LinearGradient get secondary => _flat(AppColors.secondary);

  /// Muted terracotta. Flat.
  static LinearGradient get accent => _flat(AppColors.accent);

  /// Destructive red. Flat.
  static LinearGradient get danger => _flat(AppColors.danger);

  /// Achievement gold. Flat — and reserved for badges and medals, never
  /// a general card fill.
  static LinearGradient get gold => _flat(AppColors.gold);

  /// Was the translucent sheen inside a glass pane. Now a flat card fill.
  static LinearGradient get glassSheen => _flat(AppColors.card);

  /// A flat card fill.
  static LinearGradient get cardFill => _flat(AppColors.card);

  /// A dead, hueless surface for disabled controls.
  static LinearGradient get disabled => _flat(AppColors.cardHigh);

  /// Bottom-up scrim for text laid over a photograph.
  ///
  /// **The one real gradient in the system.** Trek and product cover
  /// images are the consumers; keeping it here means every image overlay
  /// in the app shares one falloff. Tuned to the new dark background so
  /// the fade bottoms out into the page rather than into pure black.
  static const LinearGradient imageScrim = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [Color(0xE6121513), Color(0x99121513), Color(0x00121513)],
    stops: [0, 0.45, 1],
  );
}
