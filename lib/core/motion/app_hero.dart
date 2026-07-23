import 'package:doon_walkers/core/motion/app_motion.dart';
import 'package:doon_walkers/core/theme/app_dimens.dart';
import 'package:flutter/material.dart';

/// Hero-transition helpers.
///
/// Heroes are the redesign's main "this thing became that thing" device:
/// a trek's cover image on a card flies into the header of its detail
/// screen, a challenge badge grows out of its list row. They only work if
/// both ends agree on the tag, so tags are **built here, never typed as
/// string literals at the call site** — a typo produces no animation and
/// no error, which is exactly the kind of bug that never gets filed.
///
/// ```dart
/// // list
/// AppHero(tag: AppHeroTags.trekCover(trek.id), child: coverImage)
/// // detail
/// AppHero(tag: AppHeroTags.trekCover(trek.id), child: coverImage)
/// ```
abstract final class AppHeroTags {
  static String trekCover(String trekId) => 'trek-cover-$trekId';
  static String trekTitle(String trekId) => 'trek-title-$trekId';
  static String challengeBadge(String challengeId) => 'challenge-badge-$challengeId';
  static String productImage(String productId) => 'product-image-$productId';
  static String profileAvatar(String userId) => 'profile-avatar-$userId';

  /// Escape hatch for one-off pairs. Namespaced so an ad-hoc tag can
  /// never collide with a structured one above.
  static String custom(String namespace, String id) => 'hero-$namespace-$id';
}

/// A [Hero] with the app's flight behaviour baked in.
///
/// Two things it fixes that a bare `Hero` gets wrong here:
///
///  1. **Rounded corners mid-flight.** A bare hero flies the child as-is,
///     so a 24dp-rounded card visibly snaps to square while travelling
///     and back on landing. [AppHero] clips the flight to a radius that
///     interpolates between [fromRadius] and [toRadius].
///  2. **Text overflow mid-flight.** Text inside a hero briefly lays out
///     at an in-between width and throws yellow overflow stripes. Wrapping
///     the flight in a [Material] with transparent colour is the standard
///     fix, and it's applied here rather than remembered per call site.
class AppHero extends StatelessWidget {
  const AppHero({
    super.key,
    required this.tag,
    required this.child,
    this.fromRadius = AppRadius.card,
    this.toRadius = AppRadius.card,
    this.flightShuttleBuilder,
  });

  /// Build with [AppHeroTags], not a literal.
  final String tag;
  final Widget child;

  /// Corner radius at the start of the flight (the source widget's).
  final double fromRadius;

  /// Corner radius at the end (the destination's). Set to 0 when flying
  /// into a full-bleed header.
  final double toRadius;

  /// Overrides the default flight rendering entirely.
  final HeroFlightShuttleBuilder? flightShuttleBuilder;

  @override
  Widget build(BuildContext context) => Hero(
    tag: tag,
    flightShuttleBuilder: flightShuttleBuilder ?? _defaultShuttle,
    child: child,
  );

  Widget _defaultShuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final forward = flightDirection == HeroFlightDirection.push;
    final begin = forward ? fromRadius : toRadius;
    final end = forward ? toRadius : fromRadius;
    final curved = CurvedAnimation(parent: animation, curve: AppMotion.emphasized);
    final hero = (forward ? toHeroContext : fromHeroContext).widget as Hero;

    return AnimatedBuilder(
      animation: curved,
      builder: (context, _) => Material(
        type: MaterialType.transparency,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            lerpDouble(begin, end, curved.value),
          ),
          child: hero.child,
        ),
      ),
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

/// Fades and rises its child in on first build.
///
/// The app's entrance primitive, wrapping [AnimatedOpacity] +
/// [AnimatedSlide] so screens don't each hand-roll a controller. Give
/// consecutive items an increasing [index] and they arrive in sequence
/// ([AppMotion.staggerStep] apart) instead of all at once — the
/// difference between a list that *appears* and one that *assembles*.
///
/// ```dart
/// ...items.indexed.map((e) => AppReveal(index: e.$1, child: Row(...)))
/// ```
class AppReveal extends StatefulWidget {
  const AppReveal({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = AppMotion.medium,
    this.offsetY = AppMotion.enterOffsetY,
    this.curve = AppMotion.emphasized,
    this.enabled = true,
  });

  final Widget child;

  /// Position in a staggered sequence. 0 starts immediately.
  final int index;

  final Duration duration;

  /// How far the child rises, in logical pixels.
  final double offsetY;

  final Curve curve;

  /// Set false to render the child at its final state with no animation
  /// (e.g. when the platform has reduced-motion enabled).
  final bool enabled;

  @override
  State<AppReveal> createState() => _AppRevealState();
}

class _AppRevealState extends State<AppReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) {
      _controller.value = 1;
      return;
    }
    final delay = AppMotion.staggerStep * widget.index;
    if (delay == Duration.zero) {
      _controller.forward();
    } else {
      // forward(from:) after a delay rather than a delayed setState, so a
      // widget disposed during the delay doesn't touch a dead State.
      Future<void>.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final curved = CurvedAnimation(parent: _controller, curve: widget.curve);
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Opacity(
        opacity: curved.value.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, widget.offsetY * (1 - curved.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
