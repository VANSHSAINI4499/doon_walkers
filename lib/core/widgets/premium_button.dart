import 'package:doon_walkers/core/icons/app_icons.dart';
import 'package:doon_walkers/core/motion/app_motion.dart';
import 'package:doon_walkers/core/motion/pressable.dart';
import 'package:doon_walkers/core/theme/app_colors.dart';
import 'package:doon_walkers/core/theme/app_dimens.dart';
import 'package:doon_walkers/core/theme/app_gradients.dart';
import 'package:doon_walkers/core/theme/app_shadows.dart';
import 'package:doon_walkers/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Which meaning — and therefore which gradient — a [PremiumButton] carries.
enum PremiumButtonVariant {
  /// Electric green. The one thing you most want the user to do on this
  /// screen. At most one per screen.
  primary,

  /// Sky blue. A real but secondary action.
  secondary,

  /// Orange. Accent actions — "continue streak", "join challenge".
  accent,

  /// Red. Destructive and irreversible.
  danger,

  /// Gold. Achievement-flavoured actions.
  gold,

  /// Translucent glass with a hairline border. The quiet option, for
  /// actions sitting next to a filled one.
  glass,

  /// Text and icon only. Tertiary actions, inline links.
  ghost,
}

/// Height/typography preset.
enum PremiumButtonSize { small, medium, large }

/// The app's button.
///
/// A gradient-filled, generously rounded control that physically
/// responds to touch:
///
///  - **Gradient fill**, lit from the top-left like every other surface
///    in the system (see [AppGradients]).
///  - **18dp+ corners** — [AppRadius.md] (20) by default, never below
///    [AppRadius.button] (18).
///  - **Scale on press** — shrinks to [AppMotion.pressScale] while held
///    and springs back, via [Pressable].
///  - **Coloured glow** beneath it, so it reads as emitting light.
///  - **Icon + text**, on either side of the label.
///  - **A real loading state** — the label crossfades out and a spinner
///    crossfades in *without the button changing size*, so a row of
///    buttons doesn't reflow when one starts working. Taps are ignored
///    while loading, which also makes it the app's double-submit guard.
///
/// The variants ([PremiumButtonVariant]) exist so meaning drives colour
/// rather than each screen picking a gradient. Use [PremiumButton.icon]
/// for a square icon-only button.
///
/// ```dart
/// PremiumButton(
///   label: 'Register for this trek',
///   icon: AppIcons.hiking,
///   isLoading: controller.isSubmitting,
///   onPressed: _submit,
/// )
/// ```
class PremiumButton extends StatelessWidget {
  const PremiumButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = PremiumButtonVariant.primary,
    this.size = PremiumButtonSize.medium,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = false,
    this.borderRadius = AppRadius.md,
    this.haptic = true,
  }) : _iconOnly = false;

  /// A square, icon-only button — toolbar actions, floating controls.
  const PremiumButton.icon({
    super.key,
    required IconData this.icon,
    this.onPressed,
    this.variant = PremiumButtonVariant.glass,
    this.size = PremiumButtonSize.medium,
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

  final PremiumButtonVariant variant;
  final PremiumButtonSize size;

  /// Leading icon — an [AppIcons] constant. Rendered filled via [AppIcon].
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
    PremiumButtonSize.small => 40,
    PremiumButtonSize.medium => 52,
    PremiumButtonSize.large => 60,
  };

  double get _iconSize => switch (size) {
    PremiumButtonSize.small => 18,
    PremiumButtonSize.medium => 20,
    PremiumButtonSize.large => 24,
  };

  double get _horizontalPadding => switch (size) {
    PremiumButtonSize.small => AppSpacing.lg,
    PremiumButtonSize.medium => AppSpacing.xxl,
    PremiumButtonSize.large => AppSpacing.xxxl,
  };

  TextStyle get _labelStyle => switch (size) {
    PremiumButtonSize.small => AppTextStyles.labelMedium,
    PremiumButtonSize.medium => AppTextStyles.labelLarge,
    PremiumButtonSize.large => AppTextStyles.titleMedium,
  };

  /// The gradient behind the button, or null for the unfilled variants.
  Gradient? get _gradient => switch (variant) {
    PremiumButtonVariant.primary => AppGradients.primary,
    PremiumButtonVariant.secondary => AppGradients.secondary,
    PremiumButtonVariant.accent => AppGradients.accent,
    PremiumButtonVariant.danger => AppGradients.danger,
    PremiumButtonVariant.gold => AppGradients.gold,
    PremiumButtonVariant.glass => AppGradients.glassSheen,
    PremiumButtonVariant.ghost => null,
  };

  /// Label/icon colour. Filled variants use dark ink, because every fill
  /// gradient in the palette is light — white text on Electric Green is
  /// unreadable, which is the whole reason [AppColors.onPrimary] is a
  /// near-black.
  Color get _foreground => switch (variant) {
    PremiumButtonVariant.primary => AppColors.onPrimary,
    PremiumButtonVariant.secondary => AppColors.onSecondary,
    PremiumButtonVariant.accent => AppColors.onAccent,
    PremiumButtonVariant.danger => AppColors.onDanger,
    PremiumButtonVariant.gold => AppColors.onGold,
    PremiumButtonVariant.glass => AppColors.white,
    PremiumButtonVariant.ghost => AppColors.primary,
  };

  /// The hue of the glow cast beneath the button.
  Color? get _glowColor => switch (variant) {
    PremiumButtonVariant.primary => AppColors.primary,
    PremiumButtonVariant.secondary => AppColors.secondary,
    PremiumButtonVariant.accent => AppColors.accent,
    PremiumButtonVariant.danger => AppColors.danger,
    PremiumButtonVariant.gold => AppColors.gold,
    PremiumButtonVariant.glass => null,
    PremiumButtonVariant.ghost => null,
  };

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    final foreground = enabled ? _foreground : AppColors.textDisabled;
    final glow = _glowColor;

    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      gradient: enabled ? _gradient : (variant == PremiumButtonVariant.ghost ? null : AppGradients.disabled),
      border: switch (variant) {
        PremiumButtonVariant.glass => Border.all(color: AppColors.glassBorder),
        PremiumButtonVariant.ghost => Border.all(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.45)
              : AppColors.glassBorder,
        ),
        _ => null,
      },
      // Disabled and unfilled buttons cast no light.
      boxShadow: enabled && glow != null ? AppShadows.button(glow) : null,
    );

    final content = AnimatedOpacity(
      // Fades the whole content block, not the button, so the surface
      // keeps its shape while the label swaps for the spinner.
      opacity: enabled || isLoading ? 1 : 0.7,
      duration: AppMotion.fast,
      child: _PremiumButtonContent(
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
      padding: _iconOnly
          ? EdgeInsets.zero
          : EdgeInsets.symmetric(horizontal: _horizontalPadding),
      decoration: decoration,
      alignment: Alignment.center,
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

/// The label/icon/spinner stack.
///
/// Both states are always laid out; the loading state crossfades on top
/// of the label rather than replacing it, which is what keeps the
/// button's intrinsic width constant while it works.
class _PremiumButtonContent extends StatelessWidget {
  const _PremiumButtonContent({
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
        child: isLoading
            ? spinner
            : AppIcon(icon!, size: iconSize, color: foreground, key: const ValueKey('icon')),
      );
    }

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          AppIcon(icon!, size: iconSize, color: foreground),
          const SizedBox(width: AppSpacing.md),
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
          const SizedBox(width: AppSpacing.md),
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
        // Ignored for hit-testing and sizing when idle so it never
        // widens the button.
        if (isLoading) spinner,
      ],
    );
  }
}
