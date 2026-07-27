/// Skeleton loading — **the app's default loading state**, replacing bare
/// [CircularProgressIndicator]s.
///
/// A spinner tells the user "something is happening". A skeleton tells
/// them *what* is about to appear and roughly how much of it, so the real
/// content lands into a shape they have already read. It also removes the
/// layout jump a spinner always causes.
///
/// Rule: **screens load into skeletons, not spinners.** A spinner is
/// still correct in exactly two places — inside a button that is working
/// (see `AppButton.isLoading`) and on pull-to-refresh, where the content
/// is already on screen and only being replaced.
///
/// The pieces:
///  - [Shimmer] — the animated sweep. Wrap any subtree.
///  - [SkeletonBox], [SkeletonCircle], [SkeletonText] — the shapes.
///  - [SkeletonList], [SkeletonCardPlaceholder], [SkeletonStatRow] —
///    ready-made layouts for the patterns this app repeats.
///
/// Every shape resolves its colour from `AppPalette`, so the whole family
/// is light/dark aware with no call-site change.
///
/// ```dart
/// asyncValue.when(
///   loading: () => const SkeletonList(),
///   error: (e, _) => ErrorView(e),
///   data: (treks) => TrekList(treks),
/// )
/// ```
library;

import 'package:doon_walkers/core/motion/app_motion.dart';
import 'package:doon_walkers/core/theme/app_dimens.dart';
import 'package:doon_walkers/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

/// Paints a moving highlight band across everything inside it.
///
/// Implemented with a [ShaderMask] in [BlendMode.srcATop], so the sweep
/// only lights up pixels the child already painted — an arbitrary subtree
/// of skeleton shapes shimmers as one coherent surface rather than each
/// shape animating on its own schedule.
///
/// One pass takes [AppMotion.shimmer]. Slow on purpose: a fast shimmer
/// reads as a rendering glitch.
class Shimmer extends StatefulWidget {
  const Shimmer({
    super.key,
    required this.child,
    this.enabled = true,
    this.baseColor,
    this.highlightColor,
    this.duration = AppMotion.shimmer,
  });

  final Widget child;

  /// Set false to freeze the sweep — e.g. once real data has arrived but
  /// the skeleton is still crossfading out.
  final bool enabled;

  /// Resting colour of skeleton shapes. Defaults to the palette's
  /// [AppPalette.skeletonBase].
  final Color? baseColor;

  /// Colour of the travelling band. Defaults to the palette's
  /// [AppPalette.skeletonHighlight] — a small step from the base, because
  /// a big contrast makes the sweep read as a flash.
  final Color? highlightColor;

  final Duration duration;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Created eagerly here, not as a `late` inline initializer: with
    // `enabled: false` the build never touches the controller, so a lazy
    // field would first materialise inside dispose() — which spins up a
    // Ticker while the element is already deactivated and trips
    // TickerMode's ancestor lookup.
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.enabled) _controller.repeat();
  }

  @override
  void didUpdateWidget(Shimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.enabled && _controller.isAnimating) {
      _controller.stop();
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

    final palette = AppPalette.of(context);
    final base = widget.baseColor ?? palette.skeletonBase;
    final highlight = widget.highlightColor ?? palette.skeletonHighlight;

    return AnimatedBuilder(
      animation: _controller,
      builder:
          (context, child) => ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              // Travels from fully off the left to fully off the right, so
              // the band is never parked mid-frame at the loop boundary.
              final slide = -1.5 + 3 * _controller.value;
              return LinearGradient(
                begin: Alignment(slide - 0.5, -0.4),
                end: Alignment(slide + 0.5, 0.4),
                colors: [base, highlight, base],
                stops: const [0.2, 0.5, 0.8],
              ).createShader(bounds);
            },
            child: child,
          ),
      child: widget.child,
    );
  }
}

/// A rounded rectangle placeholder.
///
/// On its own it is a static block — put it under a [Shimmer] (or use one
/// of the composite skeletons below, which bring their own).
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = AppRadius.xs,
    this.margin,
  });

  /// Null stretches to the parent's width.
  final double? width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    margin: margin,
    decoration: BoxDecoration(
      color: AppPalette.of(context).skeletonBase,
      borderRadius: BorderRadius.circular(borderRadius),
    ),
  );
}

/// A circular placeholder — avatars, badges, icon slots.
class SkeletonCircle extends StatelessWidget {
  const SkeletonCircle({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppPalette.of(context).skeletonBase,
      shape: BoxShape.circle,
    ),
  );
}

/// A stack of lines standing in for a paragraph.
///
/// The last line is deliberately short ([lastLineFraction]) — that ragged
/// edge is what makes a block of bars read as *text* rather than a table.
class SkeletonText extends StatelessWidget {
  const SkeletonText({
    super.key,
    this.lines = 3,
    this.lineHeight = 12,
    this.spacing = AppSpacing.sm,
    this.lastLineFraction = 0.55,
    this.borderRadius = AppRadius.xs,
  });

  final int lines;
  final double lineHeight;
  final double spacing;

  /// Width of the final line as a fraction of the full width.
  final double lastLineFraction;

  final double borderRadius;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final fullWidth =
          constraints.maxWidth.isFinite ? constraints.maxWidth : 200.0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < lines; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == lines - 1 ? 0 : spacing),
              child: SkeletonBox(
                width:
                    i == lines - 1 ? fullWidth * lastLineFraction : fullWidth,
                height: lineHeight,
                borderRadius: borderRadius,
              ),
            ),
        ],
      );
    },
  );
}

/// One card-shaped placeholder: cover image, title, two lines of body,
/// and a row of metadata chips.
///
/// Sized to stand in for the app's dominant card shape (trek cards,
/// challenge cards, product cards) so the skeleton and the real thing
/// occupy about the same box.
class SkeletonCardPlaceholder extends StatelessWidget {
  const SkeletonCardPlaceholder({
    super.key,
    this.showImage = true,
    this.imageHeight = 150,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.borderRadius = AppRadius.card,
  });

  final bool showImage;
  final double imageHeight;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) => Shimmer(
    child: _SkeletonCardBody(
      showImage: showImage,
      imageHeight: imageHeight,
      padding: padding,
      borderRadius: borderRadius,
      showChips: true,
    ),
  );
}

/// A vertical run of card placeholders — the standard loading state for
/// any list screen (Trek Library, Challenges, Merchandise).
///
/// Wrapped in a single [Shimmer] so the sweep crosses the whole list as
/// one wave instead of every card blinking independently.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.count = 3,
    this.showImages = true,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.gap = AppSpacing.lg,
  });

  final int count;
  final bool showImages;
  final EdgeInsetsGeometry padding;
  final double gap;

  @override
  Widget build(BuildContext context) => Shimmer(
    child: Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == count - 1 ? 0 : gap),
              // The public placeholder brings its own Shimmer, which
              // would nest a second ShaderMask; use the raw body here.
              child: _SkeletonCardBody(showImage: showImages),
            ),
        ],
      ),
    ),
  );
}

/// The card placeholder's body without a [Shimmer] wrapper, so composites
/// can supply one sweep for the whole group.
class _SkeletonCardBody extends StatelessWidget {
  const _SkeletonCardBody({
    required this.showImage,
    this.imageHeight = 150,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.borderRadius = AppRadius.card,
    this.showChips = false,
  });

  final bool showImage;
  final double imageHeight;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool showChips;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showImage) SkeletonBox(height: imageHeight, borderRadius: 0),
          Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SkeletonBox(width: 180, height: 20),
                const SizedBox(height: AppSpacing.md),
                const SkeletonText(lines: 2, lineHeight: 11),
                if (showChips) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const Row(
                    children: [
                      SkeletonBox(
                        width: 64,
                        height: 26,
                        borderRadius: AppRadius.pill,
                      ),
                      SizedBox(width: AppSpacing.sm),
                      SkeletonBox(
                        width: 84,
                        height: 26,
                        borderRadius: AppRadius.pill,
                      ),
                      SizedBox(width: AppSpacing.sm),
                      SkeletonBox(
                        width: 56,
                        height: 26,
                        borderRadius: AppRadius.pill,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar + two lines — the loading state for comment threads,
/// leaderboards and registration rosters.
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({
    super.key,
    this.avatarSize = 44,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
  });

  final double avatarSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonCircle(size: avatarSize),
        const SizedBox(width: AppSpacing.md),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 120, height: 13),
              SizedBox(height: AppSpacing.sm),
              SkeletonText(lines: 2, lineHeight: 10, lastLineFraction: 0.4),
            ],
          ),
        ),
      ],
    ),
  );
}

/// A run of [SkeletonListTile]s under one shimmer sweep.
class SkeletonTileList extends StatelessWidget {
  const SkeletonTileList({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) => Shimmer(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [for (var i = 0; i < count; i++) const SkeletonListTile()],
    ),
  );
}

/// A row of big-number stat placeholders — Home community stats, Profile
/// streaks, Challenge progress.
class SkeletonStatRow extends StatelessWidget {
  const SkeletonStatRow({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) => Shimmer(
    child: Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Column(
              children: [
                SkeletonBox(width: 56, height: 34, borderRadius: AppRadius.sm),
                SizedBox(height: AppSpacing.sm),
                SkeletonBox(width: 40, height: 10),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}
