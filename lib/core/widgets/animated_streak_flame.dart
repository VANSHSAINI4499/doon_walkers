import 'package:doon_walkers/core/design_system.dart';
import 'package:flutter/material.dart';

/// A wrapper around [AppIcon] that pulses (scales and shifts opacity)
/// to signify an active streak with premium visual movement.
class AnimatedStreakFlame extends StatefulWidget {
  const AnimatedStreakFlame({
    super.key,
    required this.icon,
    required this.color,
    this.size = 20,
    this.isActive = true,
  });

  final IconData icon;
  final Color color;
  final double size;
  final bool isActive;

  @override
  State<AnimatedStreakFlame> createState() => _AnimatedStreakFlameState();
}

class _AnimatedStreakFlameState extends State<AnimatedStreakFlame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }

    _scaleAnimation = Tween<double>(
      begin: 0.94,
      end: 1.10,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _opacityAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return AppIcon(widget.icon, size: widget.size, color: widget.color);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: AppIcon(widget.icon, size: widget.size, color: widget.color),
          ),
        );
      },
    );
  }
}
