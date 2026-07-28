import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/gallery/data/services/media_cache_manager.dart';
import 'package:doon_walkers/features/gallery/domain/entities/gallery_media.dart';
import 'package:doon_walkers/features/gallery/presentation/providers/gallery_pagination_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';

/// Opens [FullScreenMediaViewer] at [initialIndex] within a trek's
/// media, ordered exactly as [trekGalleryPaginationProvider] returns
/// it (newest first) — the same provider backs [TrekGalleryScreen], so
/// an index computed from either the trek-detail preview or the full
/// masonry grid lands on the right item.
///
/// Pushed on the ROOT navigator, not the branch-local one every call
/// site actually lives in (AppShell's `StatefulShellRoute` gives each
/// bottom-nav branch its own nested Navigator). Pushing there would
/// render this viewer UNDER AppShell's own AppBar/FloatingNavBar —
/// both would stay visible around it, same issue the old
/// PhotoViewerScreen/VideoPlayerScreen had. Pushing on the root
/// Navigator instead genuinely covers them, which is the whole point
/// of an immersive fullscreen viewer. Popping restores the previous
/// branch exactly as it was; it was never touched.
Future<void> openMediaCarousel(
  BuildContext context, {
  required String trekId,
  required String trekTitle,
  required int initialIndex,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      builder:
          (context) => FullScreenMediaViewer(
            trekId: trekId,
            trekTitle: trekTitle,
            initialIndex: initialIndex,
          ),
    ),
  );
}

class FullScreenMediaViewer extends ConsumerStatefulWidget {
  const FullScreenMediaViewer({
    super.key,
    required this.trekId,
    required this.trekTitle,
    required this.initialIndex,
  });

  final String trekId;
  final String trekTitle;
  final int initialIndex;

  @override
  ConsumerState<FullScreenMediaViewer> createState() =>
      _FullScreenMediaViewerState();
}

class _FullScreenMediaViewerState extends ConsumerState<FullScreenMediaViewer> {
  late final PageController _pageController = PageController(
    initialPage: widget.initialIndex,
  );
  late int _currentIndex = widget.initialIndex;
  bool _chromeVisible = true;

  // Swipe-down-to-dismiss state.
  double _dragOffset = 0;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index, List<GalleryMedia> items) {
    setState(() => _currentIndex = index);
    // Nearing the end of what's loaded — page in more so swiping keeps
    // going through the whole trek's media, not just the batch that
    // happened to be loaded when the viewer opened.
    if (items.length - index <= 5) {
      ref
          .read(trekGalleryPaginationProvider(widget.trekId).notifier)
          .loadMore();
    }
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragging = true;
      _dragOffset = (_dragOffset + details.delta.dy).clamp(0, 600).toDouble();
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final shouldDismiss =
        _dragOffset > 120 || details.velocity.pixelsPerSecond.dy > 800;
    if (shouldDismiss) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _dragging = false;
      _dragOffset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pageAsync = ref.watch(trekGalleryPaginationProvider(widget.trekId));

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        // Belt-and-suspenders alongside dispose(): covers the system
        // back-gesture path so the chrome restore is never left a
        // frame behind the pop transition.
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: pageAsync.when(
          loading:
              () => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
          error:
              (error, stack) => const Center(
                child: Text(
                  'Could not load this gallery.',
                  style: TextStyle(color: Colors.white),
                ),
              ),
          data: (page) {
            final items = page.items;
            if (items.isEmpty) {
              return const Center(
                child: Text(
                  'No media to show.',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }
            final safeIndex = _currentIndex.clamp(0, items.length - 1).toInt();
            final double dragOpacity =
                _dragging
                    ? (1 - (_dragOffset / 500)).clamp(0.3, 1.0).toDouble()
                    : 1.0;

            return GestureDetector(
              onVerticalDragUpdate: _handleDragUpdate,
              onVerticalDragEnd: _handleDragEnd,
              onTap: () => setState(() => _chromeVisible = !_chromeVisible),
              child: Opacity(
                opacity: dragOpacity,
                child: Transform.translate(
                  offset: Offset(0, _dragOffset),
                  child: Stack(
                    children: [
                      PageView.builder(
                        controller: _pageController,
                        itemCount: items.length,
                        physics:
                            _dragging
                                ? const NeverScrollableScrollPhysics()
                                : null,
                        onPageChanged: (index) => _onPageChanged(index, items),
                        itemBuilder:
                            (context, index) => _MediaPage(
                              key: ValueKey(items[index].id),
                              media: items[index],
                              isActive: index == safeIndex,
                            ),
                      ),
                      _ChromeOverlay(
                        visible: _chromeVisible,
                        trekTitle: widget.trekTitle,
                        current: safeIndex + 1,
                        total: items.length,
                        caption: items[safeIndex].caption,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Dispatches to the right zoomable/playable content for one item,
/// wrapped in the shared hero flight from whichever [GalleryTile] it
/// was opened from — `fromRadius`/`toRadius` mirror [GalleryTile]'s own
/// so both ends of the flight agree on the corner-radius interpolation.
class _MediaPage extends StatelessWidget {
  const _MediaPage({super.key, required this.media, required this.isActive});

  final GalleryMedia media;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return AppHero(
      tag: AppHeroTags.custom('gallery', media.id),
      fromRadius: AppRadius.sm,
      toRadius: 0,
      child:
          media.mediaType == MediaType.photo
              ? _PhotoPage(media: media)
              : _VideoPage(media: media, isActive: isActive),
    );
  }
}

class _PhotoPage extends StatelessWidget {
  const _PhotoPage({required this.media});

  final GalleryMedia media;

  @override
  Widget build(BuildContext context) {
    return PhotoView(
      imageProvider: CachedNetworkImageProvider(
        media.mediaUrl,
        cacheManager: MediaCacheManager.instance.imageCacheManager,
      ),
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 4,
      loadingBuilder:
          (context, event) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
      errorBuilder:
          (context, error, stack) => const Center(
            child: AppIcon(
              AppIcons.imageBroken,
              color: Colors.white54,
              size: 48,
            ),
          ),
    );
  }
}

/// Cache-aware video page: plays instantly from disk when this URL was
/// already cached by an earlier viewing, otherwise streams from the
/// network right away and warms the cache in the background so the
/// *next* open is instant (requirement 8).
class _VideoPage extends StatefulWidget {
  const _VideoPage({required this.media, required this.isActive});

  final GalleryMedia media;
  final bool isActive;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  VideoPlayerController? _controller;
  ChewieController? _chewie;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final cachedFile = await MediaCacheManager.instance.getCachedVideoFile(
        media.mediaUrl,
      );
      final controller =
          cachedFile != null
              ? VideoPlayerController.file(cachedFile)
              : VideoPlayerController.networkUrl(Uri.parse(media.mediaUrl));

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      if (cachedFile == null) {
        MediaCacheManager.instance.precacheVideoInBackground(media.mediaUrl);
      }

      setState(() {
        _controller = controller;
        _chewie = ChewieController(
          videoPlayerController: controller,
          autoPlay: widget.isActive,
          looping: false,
        );
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load this video.');
    }
  }

  GalleryMedia get media => widget.media;

  @override
  void didUpdateWidget(covariant _VideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Pauses automatically when the carousel pages away from this
    // video (requirement 4) — PageView also disposes this State
    // outright once it's scrolled far enough that it's no longer kept
    // alive, which is what actually bounds memory on a long swipe
    // session (requirement 9); this covers the in-between frames.
    if (oldWidget.isActive && !widget.isActive) {
      _controller?.pause();
    }
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.white)),
      );
    }

    final chewie = _chewie;
    final controller = _controller;
    if (chewie == null || controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: Chewie(controller: chewie),
      ),
    );
  }
}

class _ChromeOverlay extends StatelessWidget {
  const _ChromeOverlay({
    required this.visible,
    required this.trekTitle,
    required this.current,
    required this.total,
    required this.caption,
  });

  final bool visible;
  final String trekTitle;
  final int current;
  final int total;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final hasCaption = (caption ?? '').trim().isNotEmpty;

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: AppMotion.medium,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 4,
                  right: 16,
                  bottom: 12,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const AppIcon(AppIcons.back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            trekTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '$current / $total',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
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
      ),
    );
  }
}
