import 'package:doon_walkers/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Full-screen photo view — pinch/drag to zoom via [InteractiveViewer].
/// Deliberately simple (no gallery swipe between photos) — just
/// functional per the Phase 5 brief, not an elaborate lightbox.
class PhotoViewerScreen extends StatelessWidget {
  const PhotoViewerScreen({super.key, required this.imageUrl, this.caption});

  final String imageUrl;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final hasCaption = (caption ?? '').trim().isNotEmpty;

    return Scaffold(
      // The app's own near-black rather than pure black — a lightbox
      // over a photo still deserves the brand's specific dark tone (see
      // AppColors.background's doc on why #090909 over pure #000000),
      // restyled here as part of the Phase 7 chrome sweep. The black
      // lightbox TREATMENT itself is deliberate and unchanged.
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 48,
                ),
              ),
            ),
          ),
          if (hasCaption)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: Text(
                  caption!,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
