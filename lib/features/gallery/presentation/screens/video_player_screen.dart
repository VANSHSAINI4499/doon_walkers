import 'dart:io' show Platform;

import 'package:chewie/chewie.dart';
import 'package:doon_walkers/core/theme/app_colors.dart';
import 'package:doon_walkers/core/utils/link_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Full-screen video playback for a gallery video.
///
/// video_player only ships platform implementations for Android, iOS,
/// web, and macOS — there is no Windows or Linux implementation. Per
/// product decision for Phase 5, video is mobile/web-first: on an
/// unsupported desktop platform this screen shows an explicit "not
/// supported here" state (with a link the user can open elsewhere)
/// instead of a broken/frozen player. Photos are unaffected — they
/// render everywhere via plain `Image.network`.
bool get isVideoPlaybackSupported =>
    kIsWeb || Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key, required this.videoUrl, this.caption});

  final String videoUrl;
  final String? caption;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (isVideoPlaybackSupported) {
      _initialize();
    }
  }

  Future<void> _initialize() async {
    final videoController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    try {
      await videoController.initialize();
      if (!mounted) {
        await videoController.dispose();
        return;
      }
      setState(() {
        _videoController = videoController;
        _chewieController = ChewieController(
          videoPlayerController: videoController,
          autoPlay: true,
          looping: false,
          showControls: true,
        );
      });
    } catch (error) {
      await videoController.dispose();
      if (mounted) setState(() => _error = 'Could not load this video.');
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The app's own near-black, matching PhotoViewerScreen's identical
      // Phase 7 chrome-sweep token swap — the black lightbox treatment
      // itself is unchanged.
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      body: Center(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (!isVideoPlaybackSupported) {
      return _Message(
        icon: Icons.desktop_windows_outlined,
        title: 'Video playback isn\'t supported on this platform yet.',
        actionLabel: 'Open video link',
        onAction: () => openExternalLink(context, widget.videoUrl),
      );
    }

    if (_error != null) {
      return _Message(icon: Icons.error_outline_rounded, title: _error!);
    }

    final chewie = _chewieController;
    if (chewie == null) {
      return const CircularProgressIndicator(color: Colors.white);
    }

    final hasCaption = (widget.caption ?? '').trim().isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: Chewie(controller: chewie),
        ),
        if (hasCaption)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.caption!,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, this.actionLabel, this.onAction});

  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.white54),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
