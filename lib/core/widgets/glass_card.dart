import 'dart:ui';

import 'package:doon_walkers/core/motion/app_motion.dart';
import 'package:doon_walkers/core/motion/pressable.dart';
import 'package:doon_walkers/core/theme/app_colors.dart';
import 'package:doon_walkers/core/theme/app_dimens.dart';
import 'package:doon_walkers/core/theme/app_gradients.dart';
import 'package:doon_walkers/core/theme/app_shadows.dart';
import 'package:flutter/material.dart';

/// The app's primary content surface: a **floating pane of frosted
/// glass**.
///
/// Four effects stack to produce it, and all four matter — drop any one
/// and it reads as a flat grey rectangle:
///
///  1. a [BackdropFilter] blurring whatever is behind it;
///  2. a translucent white gradient sheen, brighter at the top edge, so
///     the surface catches light from a consistent direction;
///  3. a 1px hairline border at [AppColors.glassBorder], which is what
///     actually defines the pane's edge against a dark background;
///  4. a deep black shadow for lift plus a faint coloured glow, so it
///     sits *above* the page rather than on it.
///
/// Nothing in this design system is flat, so this is the default
/// container for content — reach for it before reaching for [Card].
///
/// ## Blur costs real frames
///
/// [BackdropFilter] is one of the more expensive things you can put on
/// screen, and it costs *per instance*. A screen with a handful of glass
/// cards is fine. A scrolling list with one per row is not: set
/// [blurEnabled] to false there and the card falls back to an opaque
/// [AppColors.card] fill that keeps the same geometry, border, sheen and
/// glow. Visually it is very close on a dark background — the blur only
/// really shows when there is something textured (a photo, a gradient)
/// behind the pane.
///
/// ## Over an image
///
/// [BackdropFilter] blurs what is painted *behind* it in the same layer,
/// so a glass card only frosts something if that something is genuinely
/// behind it — a cover photo, a gradient, another card. Over the flat
/// page background there is nothing to frost and the card reads as a
/// simple translucent tint. That is expected, not a bug.
///
/// ```dart
/// GlassCard(
///   onTap: () => context.push(route),
///   glowColor: AppColors.primary,
///   child: Column(children: [...]),
/// )
/// ```
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.margin,
    this.borderRadius = AppRadius.lg,
    this.blur = AppBlur.standard,
    this.blurEnabled = true,
    this.gradient,
    this.glowColor,
    this.glowOpacity = 0.16,
    this.borderColor,
    this.borderWidth = 1,
    this.onTap,
    this.onLongPress,
    this.width,
    this.height,
    this.alignment,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  /// 24–28 is the design-spec band; [AppRadius.lg] (28) is the default.
  final double borderRadius;

  /// Backdrop blur sigma. See [AppBlur].
  final double blur;

  /// Turn the [BackdropFilter] off in favour of an opaque fill. Do this
  /// for cards inside long scrolling lists — see the class doc.
  final bool blurEnabled;

  /// Overrides the default glass sheen. Useful for cards that carry a
  /// brand tint (a "live challenge" card in green, say).
  final Gradient? gradient;

  /// Hue of the soft halo under the card. Defaults to a neutral white
  /// glow; pass a brand colour to make a card read as active/important.
  final Color? glowColor;

  /// Strength of that halo, 0–1.
  final double glowOpacity;

  /// Overrides the hairline edge colour.
  final Color? borderColor;
  final double borderWidth;

  /// Makes the whole card tappable, with the app's standard press-scale
  /// feedback (see [Pressable]).
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final glow = glowColor;

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        // With blur off there is no backdrop to tint, so the sheen has to
        // sit on top of an opaque fill or the card would be see-through
        // onto the page background.
        color: blurEnabled ? null : AppColors.card,
        gradient: gradient ?? AppGradients.glassSheen,
        border: Border.all(
          color: borderColor ?? AppColors.glassBorder,
          width: borderWidth,
        ),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (blurEnabled) {
      surface = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: surface,
      );
    }

    Widget card = DecoratedBox(
      // The shadow layer lives outside the clip: a ClipRRect would cut
      // off the very glow it is meant to cast.
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: glow == null
            ? AppShadows.glass
            : [...AppShadows.soft, ...AppShadows.glow(glow, opacity: glowOpacity, radius: 32)],
      ),
      child: ClipRRect(
        borderRadius: radius,
        clipBehavior: clipBehavior,
        child: surface,
      ),
    );

    if (width != null || height != null || alignment != null) {
      card = SizedBox(width: width, height: height, child: card);
      if (alignment != null) card = Align(alignment: alignment!, child: card);
    }

    if (margin != null) card = Padding(padding: margin!, child: card);

    if (onTap != null || onLongPress != null) {
      card = Pressable(
        onTap: onTap,
        onLongPress: onLongPress,
        scale: AppMotion.pressScaleLarge,
        borderRadius: radius,
        child: card,
      );
    }

    return card;
  }
}

/// A [GlassCard] whose glow gently breathes.
///
/// Reserved for surfaces that are genuinely *live* — an in-progress
/// challenge, a trek whose registration just opened. Ambient motion is
/// attention-grabbing by design, so more than one of these on screen at
/// a time cancels the effect out.
class PulsingGlassCard extends StatefulWidget {
  const PulsingGlassCard({
    super.key,
    required this.child,
    this.glowColor = AppColors.primary,
    this.minGlow = 0.08,
    this.maxGlow = 0.3,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.borderRadius = AppRadius.lg,
    this.onTap,
  });

  final Widget child;
  final Color glowColor;

  /// Halo opacity at the dim end of the breath.
  final double minGlow;

  /// Halo opacity at the bright end.
  final double maxGlow;

  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;

  @override
  State<PulsingGlassCard> createState() => _PulsingGlassCardState();
}

class _PulsingGlassCardState extends State<PulsingGlassCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.pulse,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      final t = Curves.easeInOut.transform(_controller.value);
      return GlassCard(
        padding: widget.padding,
        borderRadius: widget.borderRadius,
        glowColor: widget.glowColor,
        glowOpacity: widget.minGlow + (widget.maxGlow - widget.minGlow) * t,
        borderColor: Color.lerp(
          AppColors.glassBorder,
          widget.glowColor.withValues(alpha: 0.4),
          t,
        ),
        onTap: widget.onTap,
        child: child!,
      );
    },
    child: widget.child,
  );
}
