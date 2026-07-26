import 'package:doon_walkers/core/motion/app_motion.dart';
import 'package:doon_walkers/core/motion/pressable.dart';
import 'package:doon_walkers/core/theme/app_dimens.dart';
import 'package:doon_walkers/core/theme/app_palette.dart';
import 'package:doon_walkers/core/theme/app_shadows.dart';
import 'package:flutter/material.dart';

/// The app's primary content surface: a **calm, flat card**.
///
/// Three things define it, and that is deliberately all:
///
///  1. a flat fill at [AppPalette.card];
///  2. a 1px hairline at [AppPalette.border];
///  3. a level-1 shadow — small, neutral, close to the surface.
///
/// No blur, no gradient sheen, no coloured halo. The previous system
/// stacked all four of those on every card, and the result was that
/// nothing on a screen could be more important than anything else,
/// because everything glowed. Hierarchy here comes from whitespace,
/// type scale and one accent colour instead.
///
/// ```dart
/// AppCard(
///   onTap: () => context.push(route),
///   child: Column(children: [...]),
/// )
/// ```
///
/// ## Naming
///
/// [GlassCard] is a typedef onto this class. There are ~58 files still
/// constructing `GlassCard`, and they all get the calm treatment without
/// an edit; each screen's redesign phase renames its own call sites.
///
/// ## Retired parameters
///
/// [blur], [blurEnabled], [gradient], [glowColor] and [glowOpacity] are
/// accepted and **ignored**. They exist so ~96 existing call sites keep
/// compiling while the glass look disappears from all of them at once.
/// Do not pass them in new code.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.margin,
    this.borderRadius = AppRadius.card,
    this.color,
    this.borderColor,
    this.borderWidth = 1,
    this.elevation = 1,
    this.onTap,
    this.onLongPress,
    this.width,
    this.height,
    this.alignment,
    this.clipBehavior = Clip.antiAlias,
    this.blur = 0,
    this.blurEnabled = false,
    this.gradient,
    this.glowColor,
    this.glowOpacity = 0,
  });

  final Widget child;

  /// Generous by default — [AppSpacing.xl] is 24.
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  /// 16–24 is the band; [AppRadius.card] (20) is the default.
  final double borderRadius;

  /// Overrides the fill. Defaults to [AppPalette.card].
  final Color? color;

  /// Overrides the hairline. Defaults to [AppPalette.border].
  ///
  /// Tinting this is the sanctioned way to make a card read as active or
  /// important — it replaces what a coloured glow used to do, at a
  /// fraction of the visual weight.
  final Color? borderColor;

  final double borderWidth;

  /// Shadow level, 0–3. See `AppShadows`. Most cards want 1; 0 is right
  /// for a card sitting on an already-banded background.
  final int elevation;

  /// Makes the whole card tappable, with the standard press-scale.
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;
  final Clip clipBehavior;

  // ── Retired: accepted, ignored, never read ────────────────────────
  // Not marked `@Deprecated` — the annotation is accurate but would emit
  // ~96 analyzer warnings on day one and bury real findings for the whole
  // migration. The doc above is the notice.

  /// Retired — ignored. Was the backdrop blur sigma.
  final double blur;

  /// Retired — ignored. Was the blur on/off switch.
  final bool blurEnabled;

  /// Retired — ignored. Was the glass sheen override.
  final Gradient? gradient;

  /// Retired — ignored. Was the halo hue. Use [borderColor] to mark a
  /// card as important instead.
  final Color? glowColor;

  /// Retired — ignored. Was the halo strength.
  final double glowOpacity;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final radius = BorderRadius.circular(borderRadius);

    Widget card = Container(
      width: width,
      height: height,
      alignment: alignment,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: color ?? palette.card,
        borderRadius: radius,
        border: Border.all(
          color: borderColor ?? palette.border,
          width: borderWidth,
        ),
        boxShadow: AppShadows.of(palette, level: elevation),
      ),
      child: Padding(padding: padding, child: child),
    );

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

/// The previous name for [AppCard].
///
/// Kept as a typedef so the ~58 files still saying `GlassCard(...)` need
/// no edit — they simply stop being glass. New code should use [AppCard].
typedef GlassCard = AppCard;

/// Was a [GlassCard] whose glow breathed. **The pulse is retired.**
///
/// Ambient looping motion is exactly what the calm direction rules out,
/// so this now renders a static [AppCard] with a primary-tinted border —
/// which still marks a surface as live (an in-progress challenge, a trek
/// whose registration just opened) without anything moving.
///
/// Kept as a class rather than folded into [AppCard] because 5 call sites
/// construct it; the Challenges phase renames them and this goes away.
class PulsingGlassCard extends StatelessWidget {
  const PulsingGlassCard({
    super.key,
    required this.child,
    this.glowColor,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.borderRadius = AppRadius.card,
    this.onTap,
    this.minGlow = 0,
    this.maxGlow = 0,
  });

  final Widget child;

  /// Now the *border* tint rather than a halo hue. Defaults to the
  /// palette's primary.
  final Color? glowColor;

  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;

  /// Retired — ignored.
  final double minGlow;

  /// Retired — ignored.
  final double maxGlow;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return AppCard(
      padding: padding,
      borderRadius: borderRadius,
      borderColor: (glowColor ?? palette.primary).withValues(alpha: 0.55),
      onTap: onTap,
      child: child,
    );
  }
}
