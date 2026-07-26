import 'package:flutter/material.dart';

/// The app's semantic colour set, resolved **per theme** off the
/// [BuildContext].
///
/// This is the source of truth for colour in the calm redesign. It exists
/// because the previous system exposed colour as `static const Color`
/// fields on `AppColors`, which are compile-time constants with no context
/// and therefore cannot answer "what is the card colour *here*" once the
/// app has both a light and a dark theme.
///
/// ```dart
/// final palette = AppPalette.of(context);
/// Container(color: palette.card);
/// ```
///
/// ## Relationship to `AppColors`
///
/// `AppColors` still exists and still compiles — ~650 call sites across
/// the feature screens reference it, 80-odd of them from inside `const`
/// expressions that physically cannot become context-dependent. Those
/// constants have been retuned to this system's **dark** values, so an
/// unmigrated screen stays visually coherent in dark mode. Such a screen
/// will show some dark-tinted inline details in light mode until its own
/// redesign phase converts it to read from here instead. That is the
/// known, accepted cost of migrating screen by screen rather than in one
/// 650-site pass.
///
/// New code should always read from [AppPalette.of], never from
/// `AppColors`.
///
/// ## Structure
///
/// Surfaces are ordered by *depth*, not by luminance: [background] is
/// furthest back, [cardHigh] furthest forward. Code layering surfaces
/// uses the same token order in both themes and never branches on
/// brightness.
///
/// How that order is expressed differs, and has to:
///
///  - **Dark** climbs *lighter* — #12 → #2B. Lifting a dark surface
///    means adding light to it.
///  - **Light** climbs to white at [card] and then goes *slightly grey*
///    for [cardHigh]. There is nothing above white, so the topmost step
///    reads as forward by contrast instead. This is why [cardHigh] is
///    the right token for a pressed fill, a nested chip, a progress
///    track and a disabled button in both themes — in each case it needs
///    to separate from the card behind it, not to be brighter than it.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.background,
    required this.backgroundAlt,
    required this.surface,
    required this.card,
    required this.cardHigh,
    required this.border,
    required this.borderStrong,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.primarySubtle,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.accent,
    required this.onAccent,
    required this.accentContainer,
    required this.danger,
    required this.onDanger,
    required this.dangerContainer,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.textInverse,
    required this.bronze,
    required this.silver,
    required this.gold,
    required this.onGold,
    required this.platinum,
    required this.difficultyEasy,
    required this.difficultyModerate,
    required this.difficultyHard,
    required this.difficultyExtreme,
    required this.skeletonBase,
    required this.skeletonHighlight,
    required this.shadowColor,
    required this.scrim,
  });

  /// Which theme this palette belongs to. Useful for the rare widget that
  /// genuinely must branch (e.g. picking an asset variant).
  final Brightness brightness;

  // ── Surfaces, back to front ───────────────────────────────────────
  /// The page itself, behind everything.
  final Color background;

  /// Banded sections that should read as *slightly* set off from
  /// [background] without becoming a card.
  final Color backgroundAlt;

  /// Sheets, bars, and other non-floating containers.
  final Color surface;

  /// The default content card.
  final Color card;

  /// One step forward of [card] — pressed fills, nested chips on a card.
  final Color cardHigh;

  /// The hairline that defines a card's edge. In the calm system this
  /// does most of the work that glow and blur used to do.
  final Color border;

  /// A more visible border, for inputs at rest and dividers that need to
  /// be found rather than merely felt.
  final Color borderStrong;

  // ── Nature Green — the one dominant accent ────────────────────────
  final Color primary;
  final Color onPrimary;

  /// A filled container carrying primary meaning without shouting.
  final Color primaryContainer;
  final Color onPrimaryContainer;

  /// A very low-alpha primary wash, for selected rows and active pills.
  final Color primarySubtle;

  // ── Supporting hues ───────────────────────────────────────────────
  // Deliberately desaturated. The spec calls for one dominant accent, so
  // these carry *meaning* (informational, warning) rather than brand.
  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;

  final Color accent;
  final Color onAccent;
  final Color accentContainer;

  final Color danger;
  final Color onDanger;
  final Color dangerContainer;

  // ── Ink ───────────────────────────────────────────────────────────
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;

  /// Ink for use on top of [textPrimary]-coloured surfaces (inverse
  /// snackbars, tooltips).
  final Color textInverse;

  // ── Achievement metals ────────────────────────────────────────────
  // Reserved for badges, medals and tier indicators. Never a general card
  // gradient — that was the old system's habit and it is what made
  // everything look decorated rather than designed.
  //
  // The four map onto `ChallengeTier` (bronze → silver → gold → platinum),
  // which is the app's only real consumer of a metal ramp.
  final Color bronze;
  final Color silver;
  final Color gold;
  final Color onGold;
  final Color platinum;

  // ── Trek difficulty ───────────────────────────────────────────────
  final Color difficultyEasy;
  final Color difficultyModerate;
  final Color difficultyHard;
  final Color difficultyExtreme;

  // ── Loading ───────────────────────────────────────────────────────
  /// Resting colour of skeleton shapes.
  final Color skeletonBase;

  /// The travelling shimmer band. A small step from [skeletonBase]; a big
  /// contrast reads as a flash rather than a sweep.
  final Color skeletonHighlight;

  // ── Depth ─────────────────────────────────────────────────────────
  /// Base colour for elevation shadows. Shadows in this system are soft,
  /// neutral and close to the surface — see `AppShadows`.
  final Color shadowColor;

  /// Behind modals and sheets.
  final Color scrim;

  /// Reads the palette off [context], falling back to [dark] when the
  /// theme has no [AppPalette] registered.
  ///
  /// The fallback matters for widget tests and for any subtree built
  /// outside the app's own [MaterialApp]: a missing extension should
  /// degrade to a coherent palette, not a null crash.
  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>() ?? dark;

  /// The light theme's palette — airy, warm-neutral, near-white.
  ///
  /// Not pure `#FFFFFF` at the page level: a hair of warmth stops a
  /// full-screen white from reading as clinical, and gives the pure-white
  /// [card] something to sit on.
  static const AppPalette light = AppPalette(
    brightness: Brightness.light,

    background: Color(0xFFFBFBF9),
    backgroundAlt: Color(0xFFF4F5F2),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    cardHigh: Color(0xFFF1F2EF),
    border: Color(0xFFE6E7E3),
    borderStrong: Color(0xFFD3D5D0),

    primary: Color(0xFF2E7D55),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD8ECE0),
    onPrimaryContainer: Color(0xFF0E3E27),
    primarySubtle: Color(0x142E7D55),

    secondary: Color(0xFF41697F),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFDCE8EE),

    accent: Color(0xFFB1682F),
    onAccent: Color(0xFFFFFFFF),
    accentContainer: Color(0xFFF6E4D6),

    danger: Color(0xFFB3261E),
    onDanger: Color(0xFFFFFFFF),
    dangerContainer: Color(0xFFF9DEDC),

    textPrimary: Color(0xFF1A1C1A),
    textSecondary: Color(0xFF5C625E),
    textDisabled: Color(0xFF9AA09B),
    textInverse: Color(0xFFF7F8F6),

    bronze: Color(0xFF9C6B3F),
    silver: Color(0xFF7C848B),
    gold: Color(0xFFA8811C),
    onGold: Color(0xFFFFFFFF),
    platinum: Color(0xFF52707A),

    difficultyEasy: Color(0xFF2E7D55),
    difficultyModerate: Color(0xFFA8811C),
    difficultyHard: Color(0xFFB1682F),
    difficultyExtreme: Color(0xFFB3261E),

    skeletonBase: Color(0xFFEBECE8),
    skeletonHighlight: Color(0xFFF7F8F5),

    shadowColor: Color(0xFF1A1C1A),
    scrim: Color(0x661A1C1A),
  );

  /// The dark theme's palette — dark surfaces, never pure black.
  ///
  /// The old system bottomed out at `#090909`, which only worked because
  /// glass and glow were painting light back on top. With those gone, a
  /// near-black page would read as a void; these surfaces sit in the
  /// #12–#2B band so that borders and soft shadows remain visible.
  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,

    background: Color(0xFF121513),
    backgroundAlt: Color(0xFF171A18),
    surface: Color(0xFF1C201E),
    card: Color(0xFF222724),
    cardHigh: Color(0xFF2B312D),
    border: Color(0xFF333A36),
    borderStrong: Color(0xFF434B46),

    primary: Color(0xFF6BC28D),
    onPrimary: Color(0xFF06291A),
    primaryContainer: Color(0xFF1F4634),
    onPrimaryContainer: Color(0xFFA8DEC0),
    primarySubtle: Color(0x1F6BC28D),

    secondary: Color(0xFF8FB6C9),
    onSecondary: Color(0xFF102833),
    secondaryContainer: Color(0xFF264553),

    accent: Color(0xFFD79A6B),
    onAccent: Color(0xFF3A2011),
    accentContainer: Color(0xFF5B3B22),

    danger: Color(0xFFE59A94),
    onDanger: Color(0xFF3F0F0C),
    dangerContainer: Color(0xFF6B2620),

    textPrimary: Color(0xFFE8EBE9),
    textSecondary: Color(0xFFA2ABA5),
    textDisabled: Color(0xFF6E7772),
    textInverse: Color(0xFF161A17),

    bronze: Color(0xFFC9A46B),
    silver: Color(0xFFC2C8CE),
    gold: Color(0xFFE3C15A),
    onGold: Color(0xFF33280A),
    platinum: Color(0xFF9EC3CD),

    difficultyEasy: Color(0xFF6BC28D),
    difficultyModerate: Color(0xFFE3C15A),
    difficultyHard: Color(0xFFD79A6B),
    difficultyExtreme: Color(0xFFE59A94),

    skeletonBase: Color(0xFF2B312D),
    skeletonHighlight: Color(0xFF373E3A),

    shadowColor: Color(0xFF000000),
    scrim: Color(0x99000000),
  );

  @override
  AppPalette copyWith({
    Brightness? brightness,
    Color? background,
    Color? backgroundAlt,
    Color? surface,
    Color? card,
    Color? cardHigh,
    Color? border,
    Color? borderStrong,
    Color? primary,
    Color? onPrimary,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? primarySubtle,
    Color? secondary,
    Color? onSecondary,
    Color? secondaryContainer,
    Color? accent,
    Color? onAccent,
    Color? accentContainer,
    Color? danger,
    Color? onDanger,
    Color? dangerContainer,
    Color? textPrimary,
    Color? textSecondary,
    Color? textDisabled,
    Color? textInverse,
    Color? bronze,
    Color? silver,
    Color? gold,
    Color? onGold,
    Color? platinum,
    Color? difficultyEasy,
    Color? difficultyModerate,
    Color? difficultyHard,
    Color? difficultyExtreme,
    Color? skeletonBase,
    Color? skeletonHighlight,
    Color? shadowColor,
    Color? scrim,
  }) => AppPalette(
    brightness: brightness ?? this.brightness,
    background: background ?? this.background,
    backgroundAlt: backgroundAlt ?? this.backgroundAlt,
    surface: surface ?? this.surface,
    card: card ?? this.card,
    cardHigh: cardHigh ?? this.cardHigh,
    border: border ?? this.border,
    borderStrong: borderStrong ?? this.borderStrong,
    primary: primary ?? this.primary,
    onPrimary: onPrimary ?? this.onPrimary,
    primaryContainer: primaryContainer ?? this.primaryContainer,
    onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
    primarySubtle: primarySubtle ?? this.primarySubtle,
    secondary: secondary ?? this.secondary,
    onSecondary: onSecondary ?? this.onSecondary,
    secondaryContainer: secondaryContainer ?? this.secondaryContainer,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    accentContainer: accentContainer ?? this.accentContainer,
    danger: danger ?? this.danger,
    onDanger: onDanger ?? this.onDanger,
    dangerContainer: dangerContainer ?? this.dangerContainer,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textDisabled: textDisabled ?? this.textDisabled,
    textInverse: textInverse ?? this.textInverse,
    bronze: bronze ?? this.bronze,
    silver: silver ?? this.silver,
    gold: gold ?? this.gold,
    onGold: onGold ?? this.onGold,
    platinum: platinum ?? this.platinum,
    difficultyEasy: difficultyEasy ?? this.difficultyEasy,
    difficultyModerate: difficultyModerate ?? this.difficultyModerate,
    difficultyHard: difficultyHard ?? this.difficultyHard,
    difficultyExtreme: difficultyExtreme ?? this.difficultyExtreme,
    skeletonBase: skeletonBase ?? this.skeletonBase,
    skeletonHighlight: skeletonHighlight ?? this.skeletonHighlight,
    shadowColor: shadowColor ?? this.shadowColor,
    scrim: scrim ?? this.scrim,
  );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      // Brightness is categorical, not continuous — snap at the midpoint
      // rather than pretending there is a half-light theme.
      brightness: t < 0.5 ? brightness : other.brightness,
      background: c(background, other.background),
      backgroundAlt: c(backgroundAlt, other.backgroundAlt),
      surface: c(surface, other.surface),
      card: c(card, other.card),
      cardHigh: c(cardHigh, other.cardHigh),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      primary: c(primary, other.primary),
      onPrimary: c(onPrimary, other.onPrimary),
      primaryContainer: c(primaryContainer, other.primaryContainer),
      onPrimaryContainer: c(onPrimaryContainer, other.onPrimaryContainer),
      primarySubtle: c(primarySubtle, other.primarySubtle),
      secondary: c(secondary, other.secondary),
      onSecondary: c(onSecondary, other.onSecondary),
      secondaryContainer: c(secondaryContainer, other.secondaryContainer),
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      accentContainer: c(accentContainer, other.accentContainer),
      danger: c(danger, other.danger),
      onDanger: c(onDanger, other.onDanger),
      dangerContainer: c(dangerContainer, other.dangerContainer),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textDisabled: c(textDisabled, other.textDisabled),
      textInverse: c(textInverse, other.textInverse),
      bronze: c(bronze, other.bronze),
      silver: c(silver, other.silver),
      gold: c(gold, other.gold),
      onGold: c(onGold, other.onGold),
      platinum: c(platinum, other.platinum),
      difficultyEasy: c(difficultyEasy, other.difficultyEasy),
      difficultyModerate: c(difficultyModerate, other.difficultyModerate),
      difficultyHard: c(difficultyHard, other.difficultyHard),
      difficultyExtreme: c(difficultyExtreme, other.difficultyExtreme),
      skeletonBase: c(skeletonBase, other.skeletonBase),
      skeletonHighlight: c(skeletonHighlight, other.skeletonHighlight),
      shadowColor: c(shadowColor, other.shadowColor),
      scrim: c(scrim, other.scrim),
    );
  }
}
