import 'package:doon_walkers/core/motion/app_motion.dart';
import 'package:doon_walkers/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Which way a shared-axis transition travels.
enum SharedAxis {
  /// Left/right — moving between peers at the same level (tabs, steps in
  /// a form).
  horizontal,

  /// Up/down — moving between a container and something it reveals.
  vertical,

  /// Scale in/out on the Z axis — drilling *into* a thing (list → detail)
  /// when there is no hero element to carry the eye across.
  scaled,
}

/// Reusable route transitions.
///
/// Two patterns cover the whole app, straight out of the Material motion
/// spec, and later phases should not invent a third:
///
///  - **Shared axis** ([sharedAxis]) — for navigation with a *direction*:
///    forward into a detail screen, sideways between steps. The outgoing
///    and incoming pages travel along the same axis, which tells the user
///    where they went and how to get back.
///  - **Fade through** ([fadeThrough]) — for navigation *without* a
///    spatial relationship: swapping bottom-nav destinations, replacing a
///    body's content. The outgoing page fades out fully before the
///    incoming one fades and scales in, so neither implies a direction.
///
/// Each comes in two flavours: a `CustomTransitionPage` builder for
/// GoRouter's `pageBuilder`, and a `PageRoute` for imperative
/// `Navigator.push`.
///
/// ```dart
/// // GoRouter
/// GoRoute(
///   path: '/trek-library/:id',
///   pageBuilder: (context, state) => AppTransitions.sharedAxisPage(
///     key: state.pageKey,
///     child: TrekDetailScreen(trekId: state.pathParameters['id']!),
///   ),
/// )
///
/// // Navigator
/// Navigator.of(context).push(AppTransitions.fadeThroughRoute(SomeScreen()));
/// ```
abstract final class AppTransitions {
  // ── Shared axis ───────────────────────────────────────────────────

  /// The raw transition builder, so it can be dropped into any route API.
  static Widget sharedAxisTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child, {
    SharedAxis axis = SharedAxis.horizontal,
  }) {
    final entering = CurvedAnimation(parent: animation, curve: AppMotion.emphasized);
    final exiting = CurvedAnimation(parent: secondaryAnimation, curve: AppMotion.emphasized);

    // The incoming page slides in from +offset and settles at 0; the
    // outgoing page keeps travelling in the same direction to -offset,
    // so the pair reads as one continuous movement along one axis.
    Offset offsetFor(double t, {required bool incoming}) {
      const distance = 0.18;
      final magnitude = incoming ? (1 - t) * distance : -t * distance;
      return switch (axis) {
        SharedAxis.horizontal => Offset(magnitude, 0),
        SharedAxis.vertical => Offset(0, magnitude),
        SharedAxis.scaled => Offset.zero,
      };
    }

    return AnimatedBuilder(
      animation: exiting,
      builder: (context, _) => Transform.translate(
        offset: offsetFor(exiting.value, incoming: false) * _pageExtent(context, axis),
        child: Transform.scale(
          scale: axis == SharedAxis.scaled ? 1 + exiting.value * 0.1 : 1,
          child: FadeTransition(
            opacity: Tween<double>(begin: 1, end: 0).animate(exiting),
            child: AnimatedBuilder(
              animation: entering,
              builder: (context, child) => Transform.translate(
                offset: offsetFor(entering.value, incoming: true) * _pageExtent(context, axis),
                child: Transform.scale(
                  scale: axis == SharedAxis.scaled ? 0.9 + entering.value * 0.1 : 1,
                  child: Opacity(opacity: entering.value, child: child),
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  static double _pageExtent(BuildContext context, SharedAxis axis) {
    final size = MediaQuery.sizeOf(context);
    return axis == SharedAxis.vertical ? size.height : size.width;
  }

  /// GoRouter page using a shared-axis transition.
  static CustomTransitionPage<T> sharedAxisPage<T>({
    required Widget child,
    LocalKey? key,
    String? name,
    SharedAxis axis = SharedAxis.horizontal,
    Duration duration = AppMotion.page,
  }) => CustomTransitionPage<T>(
    key: key,
    name: name,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        sharedAxisTransition(context, animation, secondaryAnimation, child, axis: axis),
  );

  /// [Navigator]-pushable route using a shared-axis transition.
  static Route<T> sharedAxisRoute<T>(
    Widget child, {
    SharedAxis axis = SharedAxis.horizontal,
    Duration duration = AppMotion.page,
    RouteSettings? settings,
  }) => PageRouteBuilder<T>(
    settings: settings,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (context, animation, secondaryAnimation) => child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        sharedAxisTransition(context, animation, secondaryAnimation, child, axis: axis),
  );

  // ── Fade through ──────────────────────────────────────────────────

  /// The raw fade-through builder.
  ///
  /// Note the asymmetry: the outgoing page fades out over the first 30%
  /// of the transition and the incoming one only *starts* at 30%. That
  /// gap is what makes it read as "different place", not "moved".
  static Widget fadeThroughTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final fadeIn = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.3, 1, curve: AppMotion.emphasized),
    );
    final scaleIn = Tween<double>(begin: 0.94, end: 1).animate(fadeIn);
    final fadeOut = CurvedAnimation(
      parent: secondaryAnimation,
      curve: const Interval(0, 0.3, curve: Curves.easeOut),
    );

    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0).animate(fadeOut),
      child: FadeTransition(
        opacity: fadeIn,
        child: ScaleTransition(scale: scaleIn, child: child),
      ),
    );
  }

  /// GoRouter page using a fade-through transition.
  static CustomTransitionPage<T> fadeThroughPage<T>({
    required Widget child,
    LocalKey? key,
    String? name,
    Duration duration = AppMotion.page,
  }) => CustomTransitionPage<T>(
    key: key,
    name: name,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: fadeThroughTransition,
  );

  /// [Navigator]-pushable route using a fade-through transition.
  static Route<T> fadeThroughRoute<T>(
    Widget child, {
    Duration duration = AppMotion.page,
    RouteSettings? settings,
  }) => PageRouteBuilder<T>(
    settings: settings,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (context, animation, secondaryAnimation) => child,
    transitionsBuilder: fadeThroughTransition,
  );

  // ── Modal ─────────────────────────────────────────────────────────

  /// A full-screen modal that rises from the bottom over a dimmed page.
  /// For genuinely modal surfaces (image viewers, confirmation flows) —
  /// not for ordinary forward navigation, which should use [sharedAxis].
  static Route<T> modalRoute<T>(
    Widget child, {
    Duration duration = AppMotion.slow,
    RouteSettings? settings,
  }) => PageRouteBuilder<T>(
    settings: settings,
    opaque: false,
    barrierColor: AppColors.background.withValues(alpha: 0.7),
    transitionDuration: duration,
    reverseTransitionDuration: AppMotion.medium,
    pageBuilder: (context, animation, secondaryAnimation) => child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.emphasized,
        reverseCurve: AppMotion.exit,
      );
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}
