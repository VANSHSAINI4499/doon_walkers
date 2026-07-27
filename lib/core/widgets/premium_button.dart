import 'package:doon_walkers/core/icons/app_icons.dart';
import 'package:doon_walkers/core/motion/app_motion.dart';
import 'package:doon_walkers/core/motion/pressable.dart';
import 'package:doon_walkers/core/theme/app_dimens.dart';
import 'package:doon_walkers/core/theme/app_palette.dart';
import 'package:doon_walkers/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Which meaning — and therefore which treatment — an [AppButton] carries.
enum AppButtonVariant {
  /// Filled Nature Green. The one thing you most want the user to do on
  /// this screen. **At most one per screen** — that rule is what makes a
  /// single accent colour work as a wayfinding device.
  primary,

  /// Filled, muted slate. A real but secondary action.
  secondary,

  /// Filled, muted terracotta. Accent actions.
  accent,

  /// Filled red. Destructive and irreversible.
  danger,

  /// Filled achievement gold. Reserved for achievement-flavoured actions
  /// — claiming a badge, sharing a medal. Not a general highlight.
  gold,

  /// Outlined, transparent fill. The quiet option, sitting next to a
  /// filled one. (Was the translucent "glass" variant.)
  glass,

  /// Text and icon only, no border. Tertiary actions, inline links.
  ghost,
}

/// Height/typography preset.
enum AppButtonSize { small, medium, large }

/// The app's button — **flat fill, soft corners, scale on press**.
///
///  - **Flat fill.** The old button carried a gradient and a coloured
///    glow beneath it; both are gone. A solid accent block on a calm
///    page is already the loudest thing on screen.
///  - **16dp corners** ([AppRadius.button]).
///  - **Scale on press** via [Pressable] — the one motion the direction
///    explicitly keeps.
///  - **A real loading state.** The label crossfades out and a spinner
///    crossfades in *without the button changing size*, so a row of
///    buttons doesn't reflow. Taps are ignored while loading, which also
///    makes it the app's double-submit guard.
///
/// ```dart
/// AppButton(
///   label: 'Register for this trek',
///   icon: AppIcons.hiking,
///   isLoading: controller.isSubmitting,
///   onPressed: _submit,
/// )
/// ```
///
/// [PremiumButton] is a typedef onto this class, so the ~47 files still
/// constructing it need no edit.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = false,
    this.borderRadius = AppRadius.button,
    this.haptic = true,
  }) : _iconOnly = false;

  /// A square, icon-only button — toolbar actions, floating controls.
  const AppButton.icon({
    super.key,
    required IconData this.icon,
    this.onPressed,
    this.variant = AppButtonVariant.glass,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.borderRadius = AppRadius.button,
    this.haptic = true,
    String? tooltip,
  }) : label = tooltip ?? '',
       trailingIcon = null,
       fullWidth = false,
       _iconOnly = true;

  final String label;

  /// Null disables the button. So does [isLoading].
  final VoidCallback? onPressed;

  final AppButtonVariant variant;
  final AppButtonSize size;

  /// Leading icon — an [AppIcons] constant.
  final IconData? icon;

  /// Trailing icon, for "next"-style affordances.
  final IconData? trailingIcon;

  /// Swaps the label for a spinner and ignores taps, without resizing.
  final bool isLoading;

  /// Stretch to the parent's full width.
  final bool fullWidth;

  final double borderRadius;
  final bool haptic;

  final bool _iconOnly;

  bool get _enabled => onPressed != null && !isLoading;

  double get _height => switch (size) {
    AppButtonSize.small => 40,
    AppButtonSize.medium => 52,
    AppButtonSize.large => 56,
  };

  double get _iconSize => switch (size) {
    AppButtonSize.small => 18,
    AppButtonSize.medium => 20,
    AppButtonSize.large => 22,
  };

  double get _horizontalPadding => switch (size) {
    AppButtonSize.small => AppSpacing.lg,
    AppButtonSize.medium => AppSpacing.xl,
    AppButtonSize.large => AppSpacing.xxl,
  };

  TextStyle get _labelStyle => switch (size) {
    AppButtonSize.small => AppTextStyles.labelMedium,
    AppButtonSize.medium => AppTextStyles.labelLarge,
    AppButtonSize.large => AppTextStyles.titleMedium,
  };

  /// The flat fill, or null for the unfilled variants.
  Color? _fill(AppPalette p) => switch (variant) {
    AppButtonVariant.primary => p.primary,
    AppButtonVariant.secondary => p.secondary,
    AppButtonVariant.accent => p.accent,
    AppButtonVariant.danger => p.danger,
    AppButtonVariant.gold => p.gold,
    AppButtonVariant.glass => null,
    AppButtonVariant.ghost => null,
  };

  /// Label/icon colour.
  Color _foreground(AppPalette p) => switch (variant) {
    AppButtonVariant.primary => p.onPrimary,
    AppButtonVariant.secondary => p.onSecondary,
    AppButtonVariant.accent => p.onAccent,
    AppButtonVariant.danger => p.onDanger,
    AppButtonVariant.gold => p.onGold,
    // The unfilled variants sit on the page, so they take page ink:
    // outlined stays neutral, ghost carries the accent because it has no
    // border to signal tappability with.
    AppButtonVariant.glass => p.textPrimary,
    AppButtonVariant.ghost => p.primary,
  };

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final enabled = _enabled;
    final foreground = enabled ? _foreground(p) : p.textDisabled;
    final fill = _fill(p);

    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      color: enabled ? fill : (fill == null ? null : p.cardHigh),
      border: switch (variant) {
        AppButtonVariant.glass => Border.all(
          color: enabled ? p.borderStrong : p.border,
        ),
        AppButtonVariant.ghost => null,
        _ => null,
      },
    );

    final content = AnimatedOpacity(
      // Fades the content block, not the button, so the surface keeps its
      // shape while the label swaps for the spinner.
      opacity: enabled || isLoading ? 1 : 0.7,
      duration: AppMotion.fast,
      child: _AppButtonContent(
        label: label,
        icon: icon,
        trailingIcon: trailingIcon,
        isLoading: isLoading,
        iconOnly: _iconOnly,
        foreground: foreground,
        iconSize: _iconSize,
        labelStyle: _labelStyle.copyWith(color: foreground),
      ),
    );

    Widget button = AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      height: _height,
      width: _iconOnly ? _height : null,
      padding:
          _iconOnly
              ? EdgeInsets.zero
              : EdgeInsets.symmetric(horizontal: _horizontalPadding),
      decoration: decoration,
      // Only pin an alignment when the button's width is being imposed
      // from outside. A Container *with* an alignment expands to fill any
      // bounded constraint, which makes every button in a Wrap or a Row
      // stretch to the full line width instead of sizing to its label.
      // Without it the box sizes to the content Row (which is already
      // mainAxisSize.min and centre-aligned), and a stretched button —
      // fullWidth, or a `crossAxisAlignment: stretch` Column — still
      // centres its label correctly.
      alignment: fullWidth || _iconOnly ? Alignment.center : null,
      child: content,
    );

    if (fullWidth && !_iconOnly) {
      button = SizedBox(width: double.infinity, child: button);
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: label.isEmpty ? null : label,
      child: Pressable(
        onTap: enabled ? onPressed : null,
        haptic: haptic,
        borderRadius: BorderRadius.circular(borderRadius),
        child: button,
      ),
    );
  }
}

/// The previous name for [AppButton]. Kept as a typedef so existing call
/// sites need no edit; new code should use [AppButton].
typedef PremiumButton = AppButton;

/// The previous name for [AppButtonVariant].
typedef PremiumButtonVariant = AppButtonVariant;

/// The previous name for [AppButtonSize].
typedef PremiumButtonSize = AppButtonSize;

/// The label/icon/spinner stack.
///
/// Both states are always laid out; the loading state crossfades on top
/// of the label rather than replacing it, which is what keeps the
/// button's intrinsic width constant while it works.
class _AppButtonContent extends StatelessWidget {
  const _AppButtonContent({
    required this.label,
    required this.icon,
    required this.trailingIcon,
    required this.isLoading,
    required this.iconOnly,
    required this.foreground,
    required this.iconSize,
    required this.labelStyle,
  });

  final String label;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool isLoading;
  final bool iconOnly;
  final Color foreground;
  final double iconSize;
  final TextStyle labelStyle;

  @override
  Widget build(BuildContext context) {
    final spinner = SizedBox(
      width: iconSize,
      height: iconSize,
      child: CircularProgressIndicator(
        strokeWidth: 2.2,
        valueColor: AlwaysStoppedAnimation<Color>(foreground),
      ),
    );

    if (iconOnly) {
      return AnimatedSwitcher(
        duration: AppMotion.fast,
        child:
            isLoading
                ? spinner
                : AppIcon(
                  icon!,
                  size: iconSize,
                  color: foreground,
                  key: const ValueKey('icon'),
                ),
      );
    }

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          AppIcon(icon!, size: iconSize, color: foreground),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            label,
            style: labelStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: AppSpacing.sm),
          AppIcon(trailingIcon!, size: iconSize, color: foreground),
        ],
      ],
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedOpacity(
          opacity: isLoading ? 0 : 1,
          duration: AppMotion.fast,
          child: row,
        ),
        // Only mounted while loading so it never widens the button.
        if (isLoading) spinner,
      ],
    );
  }
}
