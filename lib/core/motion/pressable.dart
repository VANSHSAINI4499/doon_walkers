import 'package:doon_walkers/core/motion/app_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps any widget so it **scales down while pressed** and springs back
/// on release.
///
/// This is the app's single press-feedback primitive. Material's own ink
/// ripple is disabled inside it by default: a ripple spreading across a
/// blurred glass surface muddies the blur and fights the scale, so the
/// redesign uses scale (plus an optional brightness lift) as the press
/// affordance instead. Pass [showRipple] if a particular surface really
/// does want ink.
///
/// Used by `PremiumButton` and by `GlassCard` when it is tappable, so a
/// card and a button pressed on the same screen respond identically.
///
/// ```dart
/// Pressable(
///   onTap: () => context.push(route),
///   child: GlassCard(child: ...),
/// )
/// ```
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = AppMotion.pressScale,
    this.duration = AppMotion.instant,
    this.curve = AppMotion.standard,
    this.releaseCurve = AppMotion.spring,
    this.haptic = true,
    this.showRipple = false,
    this.borderRadius,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Scale applied while held. 1.0 disables the effect.
  final double scale;

  /// How long the shrink takes. The release uses the same duration but
  /// [releaseCurve], so it springs back rather than easing back.
  final Duration duration;
  final Curve curve;
  final Curve releaseCurve;

  /// Fires a light impact on press. Off for non-committal taps.
  final bool haptic;

  /// Draw a Material ink ripple as well. Off by default — see class doc.
  final bool showRipple;

  /// Clips the ripple, when [showRipple] is on. Match the child's radius.
  final BorderRadius? borderRadius;

  final HitTestBehavior behavior;

  /// True when this instance is actually interactive.
  bool get _enabled => onTap != null || onLongPress != null;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handleTap() {
    if (widget.haptic) HapticFeedback.lightImpact();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget._enabled) return widget.child;

    Widget content = AnimatedScale(
      scale: _pressed ? widget.scale : 1,
      duration: widget.duration,
      curve: _pressed ? widget.curve : widget.releaseCurve,
      child: widget.child,
    );

    if (widget.showRipple) {
      content = Material(
        color: Colors.transparent,
        borderRadius: widget.borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _handleTap,
          onLongPress: widget.onLongPress,
          onHighlightChanged: _setPressed,
          borderRadius: widget.borderRadius,
          child: content,
        ),
      );
      return content;
    }

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: _handleTap,
      onLongPress: widget.onLongPress,
      child: content,
    );
  }
}
