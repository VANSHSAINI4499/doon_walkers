import 'package:doon_walkers/core/theme/app_dimens.dart';
import 'package:doon_walkers/core/theme/app_palette.dart';
import 'package:doon_walkers/core/theme/app_shadows.dart';
import 'package:doon_walkers/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// DoonWalkers Material 3 theme — **light and dark**.
///
/// Both themes are generated from one builder fed a different
/// [AppPalette], so they cannot drift apart: a widget styled here is
/// styled identically in both, only the colours differ. The palette is
/// also registered as a [ThemeExtension], which is how components reach
/// semantic colours that Material's own [ColorScheme] has no slot for
/// (achievement metals, trek difficulty, skeleton shimmer).
///
/// Wire it up as:
///
/// ```dart
/// MaterialApp(
///   theme: AppTheme.light,
///   darkTheme: AppTheme.dark,
///   themeMode: ref.watch(themeModeProvider),
/// )
/// ```
///
/// ## What this theme is responsible for
///
/// Everything Material draws: app bars, nav bars, inputs, cards, chips,
/// dialogs, sheets, snackbars. Because feature screens lean heavily on
/// stock Material widgets plus the shared components, styling it properly
/// here is what makes the majority of each screen theme-aware without
/// opening the screen.
///
/// The shared components (`AppCard`/`GlassCard`, `PremiumButton`, the
/// stat displays, the skeleton family) read [AppPalette] directly rather
/// than being expressible as [ThemeData].
abstract final class AppTheme {
  AppTheme._();

  /// The light theme — airy, near-white, generous.
  static ThemeData get light => _build(AppPalette.light);

  /// The dark theme — dark surfaces, never pure black.
  static ThemeData get dark => _build(AppPalette.dark);

  static ThemeData _build(AppPalette p) {
    final isDark = p.brightness == Brightness.dark;
    final textTheme = AppTextStyles.textTheme(
      ink: p.textPrimary,
      dimInk: p.textSecondary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: _scheme(p),
      extensions: [p],
      textTheme: textTheme,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      shadowColor: p.shadowColor,
      dividerColor: p.border,

      // The calm system's press affordance is a small scale (see
      // `Pressable`), not an ink ripple. Killing the default splash keeps
      // stock Material widgets consistent with the custom ones.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,

      // ── App bar ────────────────────────────────────────────────────
      // Flat and page-coloured, so content starts at the top of the
      // screen with no visible chrome band.
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: p.textPrimary),
        actionsIconTheme: IconThemeData(color: p.textPrimary),
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),

      // ── Bottom navigation ──────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.primarySubtle,
        indicatorShape: const StadiumBorder(),
        elevation: 0,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color:
                states.contains(WidgetState.selected)
                    ? p.primary
                    : p.textSecondary,
            size: 24,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppTextStyles.labelSmall.copyWith(
            color:
                states.contains(WidgetState.selected)
                    ? p.primary
                    : p.textSecondary,
          ),
        ),
      ),

      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.primarySubtle,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.all(textTheme.titleSmall),
      ),

      // ── Cards ──────────────────────────────────────────────────────
      // Flat fill, hairline border, no shadow at rest. Stock [Card] is
      // the fallback for screens not yet migrated to `AppCard`; matching
      // the two keeps them from reading as different systems.
      cardTheme: CardThemeData(
        color: p.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: p.border),
        ),
      ),

      // ── Buttons ────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          disabledBackgroundColor: p.cardHigh,
          disabledForegroundColor: p.textDisabled,
          minimumSize: const Size(double.infinity, 52),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: AppTextStyles.labelLarge,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          disabledBackgroundColor: p.cardHigh,
          disabledForegroundColor: p.textDisabled,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: AppTextStyles.labelLarge,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.primary,
          minimumSize: const Size(0, 52),
          side: BorderSide(color: p.borderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: AppTextStyles.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          textStyle: AppTextStyles.labelLarge,
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: p.textPrimary),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
      ),

      // ── Inputs ─────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // A hair off the card colour so a field reads as an inset well
        // rather than as another card.
        fillColor: isDark ? p.cardHigh : p.backgroundAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: p.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: p.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: p.danger, width: 1.6),
        ),
        labelStyle: AppTextStyles.bodyMedium.copyWith(color: p.textSecondary),
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: p.textDisabled),
        floatingLabelStyle: AppTextStyles.labelMedium.copyWith(
          color: p.primary,
        ),
        prefixIconColor: p.textSecondary,
        suffixIconColor: p.textSecondary,
      ),

      // ── Chips ──────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? p.cardHigh : p.backgroundAlt,
        selectedColor: p.primaryContainer,
        disabledColor: p.backgroundAlt,
        labelStyle: AppTextStyles.labelMedium.copyWith(color: p.textPrimary),
        secondaryLabelStyle: AppTextStyles.labelMedium.copyWith(
          color: p.onPrimaryContainer,
        ),
        side: BorderSide(color: p.border),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),

      // ── Surfaces & overlays ────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: p.border),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.top(AppRadius.xl),
        ),
        showDragHandle: true,
        dragHandleColor: p.borderStrong,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        // Inverse surface: a snackbar is a temporary intrusion and should
        // read as *not* part of the page.
        backgroundColor: p.textPrimary,
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(
          color: p.textInverse,
        ),
        actionTextColor: p.primary,
        elevation: 0,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        textStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(color: p.border),
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.textPrimary,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        textStyle: AppTextStyles.labelSmall.copyWith(color: p.textInverse),
      ),

      // ── Misc ───────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.cardHigh,
        circularTrackColor: p.cardHigh,
        linearMinHeight: 6,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        textColor: p.textPrimary,
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: AppTextStyles.bodySmall.copyWith(
          color: p.textSecondary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? p.onPrimary
                  : p.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? p.primary : p.cardHigh,
        ),
        trackOutlineColor: WidgetStateProperty.all(p.border),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? p.primary
                  : Colors.transparent,
        ),
        checkColor: WidgetStateProperty.all(p.onPrimary),
        side: BorderSide(color: p.borderStrong, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? p.primary
                  : p.borderStrong,
        ),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: p.primary,
        unselectedLabelColor: p.textSecondary,
        labelStyle: AppTextStyles.labelLarge,
        unselectedLabelStyle: AppTextStyles.labelLarge,
        indicatorColor: p.primary,
        dividerColor: p.border,
      ),
    );
  }

  /// The Material 3 colour scheme for [p].
  ///
  /// Written out explicitly rather than derived with
  /// [ColorScheme.fromSeed]: the palette is fixed by the design
  /// direction, and a seed algorithm would quietly re-derive every
  /// container and "on-" colour into something adjacent-but-different.
  static ColorScheme _scheme(AppPalette p) => ColorScheme(
    brightness: p.brightness,

    primary: p.primary,
    onPrimary: p.onPrimary,
    primaryContainer: p.primaryContainer,
    onPrimaryContainer: p.onPrimaryContainer,

    secondary: p.secondary,
    onSecondary: p.onSecondary,
    secondaryContainer: p.secondaryContainer,
    onSecondaryContainer: p.textPrimary,

    tertiary: p.accent,
    onTertiary: p.onAccent,
    tertiaryContainer: p.accentContainer,
    onTertiaryContainer: p.textPrimary,

    error: p.danger,
    onError: p.onDanger,
    errorContainer: p.dangerContainer,
    onErrorContainer: p.textPrimary,

    surface: p.surface,
    onSurface: p.textPrimary,
    onSurfaceVariant: p.textSecondary,

    surfaceContainerLowest: p.background,
    surfaceContainerLow: p.backgroundAlt,
    surfaceContainer: p.surface,
    surfaceContainerHigh: p.card,
    surfaceContainerHighest: p.cardHigh,

    outline: p.borderStrong,
    outlineVariant: p.border,

    inverseSurface: p.textPrimary,
    onInverseSurface: p.textInverse,
    inversePrimary: p.primaryContainer,

    shadow: p.shadowColor,
    scrim: p.scrim,
  );
}

/// Convenience accessors used by the shared components.
extension AppThemeContext on BuildContext {
  /// The active semantic palette.
  AppPalette get palette => AppPalette.of(this);

  /// Elevation shadows tuned for the active theme.
  List<BoxShadow> elevation([int level = 1]) =>
      AppShadows.of(AppPalette.of(this), level: level);
}
