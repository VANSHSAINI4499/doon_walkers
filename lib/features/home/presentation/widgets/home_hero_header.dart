import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/settings/presentation/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full-bleed hero at the top of Home.
///
/// Data-wise it is unchanged from before: it greets the visitor with the
/// community tagline pulled live from [settingsProvider], falling back to
/// [AppConstants.appTagline] while settings load or if `org_tagline` is
/// empty, so the headline is never blank.
///
/// Visually it is a full redesign onto the Phase 1 system: a layered,
/// code-drawn dusk-mountain "photograph" (there is no real cover image in
/// `settings`, and inventing a network image / bundling an asset would be
/// adding data, not restyling — so the imagery is painted from the brand
/// palette in [_HeroBackdrop]), a dark scrim for legibility, and a frosted
/// [GlassCard] greeting floating over it. The greeting card keeps its
/// backdrop blur *on* — unlike Home's other cards — precisely because it
/// has the mountains behind it to frost.
class HomeHeroHeader extends ConsumerWidget {
  const HomeHeroHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).valueOrNull;
    final tagline = settings == null || settings.orgTagline.isEmpty
        ? AppConstants.appTagline
        : settings.orgTagline;

    return SizedBox(
      // Trimmed from 300 — the greeting card is bottom-anchored, so a
      // taller band just meant more empty painted sky above it before
      // any real content appeared.
      height: 232,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _HeroBackdrop(),
          // Bottom-up scrim so the glass card and its text stay legible
          // over the brighter parts of the painted sky.
          const DecoratedBox(
            decoration: BoxDecoration(gradient: AppGradients.imageScrim),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              child: AppReveal(
                child: _GreetingCard(tagline: tagline),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.tagline});

  final String tagline;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      // Blur ON here on purpose: it frosts the mountains behind it. Home's
      // other cards sit over the flat page background and keep blur off.
      borderRadius: AppRadius.lg,
      glowColor: AppColors.primary,
      glowOpacity: 0.22,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const AppIcon(
                  AppIcons.hiking,
                  size: 18,
                  color: AppColors.onPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'NAMASTE, TREKKER 🙏',
                style: AppTextStyles.tinted(
                  AppTextStyles.overline,
                  AppColors.primaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            tagline,
            style: AppTextStyles.headlineMedium.copyWith(height: 1.1),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// The painted hero "photograph": a dusk sky with two aurora-like brand
/// glows and three receding mountain ridgelines with snow highlights.
///
/// Entirely deterministic and cheap to paint (no images, no per-frame
/// work), so it is const and repaints only on resize.
class _HeroBackdrop extends StatelessWidget {
  const _HeroBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // Sky: darkest at the very top so it melts into the app bar above,
      // warming into deep blue-green toward the ridgeline.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.background,
            Color(0xFF0B1A16),
            Color(0xFF0E2622),
          ],
          stops: [0, 0.5, 1],
        ),
      ),
      child: CustomPaint(
        painter: _MountainPainter(),
        size: Size.infinite,
      ),
    );
  }
}

class _MountainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Two soft brand glows high in the sky — the "aurora".
    canvas.drawCircle(
      Offset(w * 0.22, h * 0.18),
      w * 0.42,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.20),
            AppColors.primary.withValues(alpha: 0),
          ],
        ).createShader(
          Rect.fromCircle(center: Offset(w * 0.22, h * 0.18), radius: w * 0.42),
        ),
    );
    canvas.drawCircle(
      Offset(w * 0.82, h * 0.10),
      w * 0.38,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.secondary.withValues(alpha: 0.16),
            AppColors.secondary.withValues(alpha: 0),
          ],
        ).createShader(
          Rect.fromCircle(center: Offset(w * 0.82, h * 0.10), radius: w * 0.38),
        ),
    );

    // Three ridgelines, back (palest/faded) to front (darkest).
    _ridge(
      canvas,
      size,
      baseline: h * 0.62,
      peaks: const [0.30, 0.16, 0.42, 0.24, 0.36],
      color: const Color(0xFF16302A),
    );
    _ridge(
      canvas,
      size,
      baseline: h * 0.74,
      peaks: const [0.20, 0.40, 0.16, 0.34, 0.22],
      color: const Color(0xFF10241F),
      snow: true,
    );
    _ridge(
      canvas,
      size,
      baseline: h * 0.88,
      peaks: const [0.34, 0.18, 0.30, 0.14, 0.26],
      color: const Color(0xFF0A1613),
    );
  }

  /// Draws one mountain layer as a jagged path from left to right along
  /// [peaks] (each a height fraction above [baseline]), filled down to the
  /// bottom edge. Optionally caps the highest points with a faint snow
  /// highlight.
  void _ridge(
    Canvas canvas,
    Size size, {
    required double baseline,
    required List<double> peaks,
    required Color color,
    bool snow = false,
  }) {
    final w = size.width;
    final h = size.height;
    final path = Path()..moveTo(0, baseline);

    final step = w / (peaks.length - 1);
    for (var i = 0; i < peaks.length; i++) {
      final x = step * i;
      final y = baseline - h * peaks[i];
      if (i == 0) {
        path.lineTo(x, y);
      } else {
        // A small mid-point valley between peaks keeps the ridge jagged
        // rather than a smooth zigzag.
        final prevX = step * (i - 1);
        final midX = (prevX + x) / 2;
        final midY = baseline - h * (peaks[i] * 0.35);
        path
          ..lineTo(midX, midY)
          ..lineTo(x, y);
      }
    }
    path
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(path, Paint()..color = color);

    if (snow) {
      final snowPaint = Paint()..color = AppColors.white.withValues(alpha: 0.06);
      for (var i = 0; i < peaks.length; i++) {
        final x = step * i;
        final y = baseline - h * peaks[i];
        if (peaks[i] < 0.3) continue; // only the taller peaks get snow
        final cap = Path()
          ..moveTo(x, y)
          ..lineTo(x - 10, y + 16)
          ..lineTo(x + 10, y + 16)
          ..close();
        canvas.drawPath(cap, snowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
