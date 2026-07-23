import 'package:doon_walkers/core/theme/app_colors.dart';
import 'package:doon_walkers/core/theme/app_dimens.dart';
import 'package:doon_walkers/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// DoonWalkers Material 3 theme — **dark only**.
///
/// The redesign ships one theme. There is no light variant and no
/// [ThemeMode] toggle: the palette, the glass surfaces, the glows and the
/// contrast ratios in this design system are all built for a near-black
/// background, and a light mirror of them would be a different design,
/// not a setting.
///
/// Wire it up as *both* `theme` and `darkTheme` with
/// `themeMode: ThemeMode.dark` so the OS-level light/dark setting can't
/// pull the app into an unstyled light Material default.
///
/// ## What this theme is and isn't responsible for
///
/// It styles the **Material widgets the app already uses** — app bars,
/// nav bars, inputs, dialogs, snackbars — so pre-redesign screens land
/// somewhere coherent the moment the theme flips, rather than staying
/// light-on-light. It is *not* where the redesign's own components live:
/// `GlassCard`, `PremiumButton` and the skeleton family are explicit
/// widgets, because their look (backdrop blur, gradient fill, coloured
/// glow) is not expressible as [ThemeData].
abstract final class AppTheme {
  AppTheme._();

  /// The app's only theme.
  static ThemeData get dark {
    final colorScheme = _colorScheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: AppTextStyles.textTheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,

      // Ink splashes on top of blurred glass smear the blur, and the
      // redesign uses scale (see `Pressable`) as its press affordance
      // instead. Killing the default splash app-wide keeps stock
      // Material widgets consistent with the custom ones.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,

      // ── App bar ────────────────────────────────────────────────────
      // Flat and background-coloured: on a dark theme, an app bar that
      // matches the page reads as no chrome at all, which is what lets
      // content start at the top of the screen.
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.titleLarge,
        iconTheme: const IconThemeData(color: AppColors.white),
        actionsIconTheme: const IconThemeData(color: AppColors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),

      // ── Bottom navigation ──────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primary.withValues(alpha: 0.16),
        indicatorShape: const StadiumBorder(),
        elevation: 0,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textSecondary,
            size: 24,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppTextStyles.labelSmall.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
        ),
      ),

      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primary.withValues(alpha: 0.16),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.all(AppTextStyles.titleSmall),
      ),

      // ── Cards ──────────────────────────────────────────────────────
      // Stock [Card] is the fallback for screens not yet migrated to
      // `GlassCard`; matching its radius and border to the glass surface
      // keeps the two from looking like different systems in the
      // meantime.
      cardTheme: CardThemeData(
        color: AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
      ),

      // ── Buttons ────────────────────────────────────────────────────
      // `PremiumButton` is the redesign's button; these keep stock
      // Material buttons on-brand until every screen has migrated.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.cardHigh,
          disabledForegroundColor: AppColors.textDisabled,
          minimumSize: const Size(double.infinity, 52),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTextStyles.labelLarge,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.cardHigh,
          disabledForegroundColor: AppColors.textDisabled,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTextStyles.labelLarge,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(0, 52),
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.45)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTextStyles.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTextStyles.labelLarge,
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.white),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),

      // ── Inputs ─────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.6),
        ),
        labelStyle: AppTextStyles.secondary(AppTextStyles.bodyMedium),
        hintStyle: AppTextStyles.disabled(AppTextStyles.bodyMedium),
        floatingLabelStyle: AppTextStyles.labelMedium.copyWith(
          color: AppColors.primary,
        ),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
      ),

      // ── Chips ──────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.card,
        selectedColor: AppColors.primary.withValues(alpha: 0.18),
        disabledColor: AppColors.surface,
        labelStyle: AppTextStyles.labelMedium,
        secondaryLabelStyle: AppTextStyles.labelMedium,
        side: const BorderSide(color: AppColors.glassBorder),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),

      // ── Surfaces & overlays ────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
        titleTextStyle: AppTextStyles.titleLarge,
        contentTextStyle: AppTextStyles.bodyMedium,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.top(AppRadius.xl),
        ),
        showDragHandle: true,
        dragHandleColor: AppColors.textDisabled,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.cardHigh,
        contentTextStyle: AppTextStyles.bodyMedium,
        actionTextColor: AppColors.primary,
        elevation: 0,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.cardHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        textStyle: AppTextStyles.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.cardHigh,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          border: Border.all(color: AppColors.glassBorder),
        ),
        textStyle: AppTextStyles.labelSmall,
      ),

      // ── Misc ───────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.glassBorder,
        thickness: 1,
        space: 1,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.cardHigh,
        circularTrackColor: AppColors.cardHigh,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        titleTextStyle: AppTextStyles.titleSmall,
        subtitleTextStyle: AppTextStyles.secondary(AppTextStyles.bodySmall),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.onPrimary
              : AppColors.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.cardHigh,
        ),
        trackOutlineColor: WidgetStateProperty.all(AppColors.glassBorder),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : Colors.transparent,
        ),
        checkColor: WidgetStateProperty.all(AppColors.onPrimary),
        side: const BorderSide(color: AppColors.textDisabled, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.textDisabled,
        ),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: AppTextStyles.labelLarge,
        unselectedLabelStyle: AppTextStyles.labelLarge,
        indicatorColor: AppColors.primary,
        dividerColor: AppColors.glassBorder,
      ),
    );
  }

  /// The Material 3 colour scheme behind [dark].
  ///
  /// Written out explicitly rather than derived with
  /// [ColorScheme.fromSeed]: the palette is fixed by the design spec, and
  /// a seed algorithm would quietly re-derive every container and
  /// "on-" colour into something adjacent-but-different.
  static ColorScheme get _colorScheme => const ColorScheme(
    brightness: Brightness.dark,

    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: AppColors.primaryLight,

    secondary: AppColors.secondary,
    onSecondary: AppColors.onSecondary,
    secondaryContainer: AppColors.secondaryContainer,
    onSecondaryContainer: AppColors.secondaryLight,

    tertiary: AppColors.accent,
    onTertiary: AppColors.onAccent,
    tertiaryContainer: AppColors.accentDark,
    onTertiaryContainer: AppColors.accentLight,

    error: AppColors.danger,
    onError: AppColors.onDanger,
    errorContainer: Color(0xFF7F1D1D),
    onErrorContainer: Color(0xFFFCA5A5),

    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,

    surfaceContainerLowest: AppColors.background,
    surfaceContainerLow: AppColors.backgroundAlt,
    surfaceContainer: AppColors.surface,
    surfaceContainerHigh: AppColors.card,
    surfaceContainerHighest: AppColors.cardHigh,

    outline: AppColors.glassBorder,
    outlineVariant: AppColors.glassBorder,

    inverseSurface: AppColors.white,
    onInverseSurface: AppColors.background,
    inversePrimary: AppColors.primaryDark,

    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );
}
