import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/gallery/presentation/providers/gallery_pagination_provider.dart';
import 'package:doon_walkers/features/gallery/presentation/screens/full_screen_media_viewer.dart';
import 'package:doon_walkers/features/gallery/presentation/widgets/gallery_tile.dart';
import 'package:doon_walkers/features/gallery/presentation/widgets/gallery_upload_sheet.dart';
import 'package:doon_walkers/features/gallery/presentation/widgets/media_admin_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

/// The full, paginated masonry gallery for a trek — reached from
/// [TrekGalleryPreview]'s "+N · View All" tile once a trek has more
/// than 5 items. Backed by the SAME [trekGalleryPaginationProvider]
/// the fullscreen viewer swipes through, so scrolling here and
/// swiping there both page into one growing, shared list — sliver-
/// based masonry, so it stays smooth whether the trek has 50 items or
/// 500 (requirement 9).
class TrekGalleryScreen extends ConsumerStatefulWidget {
  const TrekGalleryScreen({super.key, required this.trekId, required this.trekTitle});

  final String trekId;
  final String trekTitle;

  @override
  ConsumerState<TrekGalleryScreen> createState() => _TrekGalleryScreenState();
}

class _TrekGalleryScreenState extends ConsumerState<TrekGalleryScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 600) {
      ref.read(trekGalleryPaginationProvider(widget.trekId).notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_maybeLoadMore);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final pageAsync = ref.watch(trekGalleryPaginationProvider(widget.trekId));

    return Scaffold(
      appBar: AppBar(title: Text(widget.trekTitle)),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => showGalleryUploadSheet(context, trekId: widget.trekId),
              child: const AppIcon(AppIcons.addPhoto, color: AppColors.onPrimary),
            )
          : null,
      body: pageAsync.when(
        loading: () => const _GalleryScreenSkeleton(),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Could not load this gallery.',
                  style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
                ),
                const SizedBox(height: AppSpacing.md),
                PremiumButton(
                  label: 'Retry',
                  variant: PremiumButtonVariant.ghost,
                  size: PremiumButtonSize.small,
                  onPressed: () => ref.invalidate(trekGalleryPaginationProvider(widget.trekId)),
                ),
              ],
            ),
          ),
        ),
        data: (page) {
          final items = page.items;
          if (items.isEmpty) {
            return Center(
              child: Text(
                'No photos or videos for this trek yet.',
                style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
              ),
            );
          }

          return MasonryGridView.count(
            controller: _scrollController,
            crossAxisCount: 2,
            padding: const EdgeInsets.all(AppSpacing.lg),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            itemCount: items.length + (page.isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= items.length) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final item = items[index];
              void openTapped() => openMediaCarousel(
                    context,
                    trekId: widget.trekId,
                    trekTitle: widget.trekTitle,
                    initialIndex: index,
                  );

              return isAdmin
                  ? MediaAdminOverlay(media: item, trekTitle: widget.trekTitle, onTap: openTapped)
                  : GalleryTile(media: item, onTap: openTapped);
            },
          );
        },
      ),
    );
  }
}

class _GalleryScreenSkeleton extends StatelessWidget {
  const _GalleryScreenSkeleton();

  static const _heights = [180.0, 130.0, 150.0, 200.0, 140.0, 170.0];

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: MasonryGridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(AppSpacing.lg),
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        itemCount: _heights.length,
        itemBuilder: (context, index) =>
            SkeletonBox(height: _heights[index], borderRadius: AppRadius.sm),
      ),
    );
  }
}
