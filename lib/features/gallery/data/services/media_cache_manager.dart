import 'dart:async';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// One shared, size- and age-bounded disk cache for every piece of
/// gallery media in the app — images AND video files.
///
/// Photos go through this indirectly: every `CachedNetworkImage`/
/// `CachedNetworkImageProvider` in the gallery is passed
/// [imageCacheManager] via its `cacheManager:` parameter, which gives
/// "load once / store locally / open instantly next time / work
/// offline after first view" for free (requirement 7) — no custom code
/// needed beyond wiring this one instance everywhere instead of each
/// widget defaulting to its own `DefaultCacheManager`.
///
/// Video has no such off-the-shelf widget, so [getCachedVideoFile] and
/// [precacheVideoInBackground] below are used directly by the
/// fullscreen video player (requirement 8): first playback streams
/// straight from the network for a fast start, then a background
/// download primes this same cache so the *next* open is instant.
///
/// A single `Config` — same `stalePeriod`/`maxNrOfCacheObjects` — auto-
/// evicts old images and videos together (least-recently-used past the
/// cap, or past 14 days unused), rather than each media type needing
/// its own eviction policy.
class MediaCacheManager {
  MediaCacheManager._();

  static final MediaCacheManager instance = MediaCacheManager._();

  final CacheManager imageCacheManager = CacheManager(
    Config(
      'doonWalkersMediaCache',
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 300,
    ),
  );

  /// Checks the cache for [url] WITHOUT triggering a download — returns
  /// null immediately if it isn't already cached. Used to decide
  /// whether a video page can start from a local file (instant) or
  /// needs to stream from the network first.
  Future<File?> getCachedVideoFile(String url) async {
    final info = await imageCacheManager.getFileFromCache(url);
    return info?.file;
  }

  /// Fire-and-forget download into the shared cache — called right
  /// after a video starts streaming from the network, so the file is
  /// ready locally by the time it's opened again ("instant replay").
  /// Failures are swallowed: this is a caching optimization, never a
  /// reason to disrupt playback that's already working.
  void precacheVideoInBackground(String url) {
    unawaited(_downloadQuietly(url));
  }

  Future<void> _downloadQuietly(String url) async {
    try {
      await imageCacheManager.getSingleFile(url);
    } catch (_) {
      // Caching optimization only — never a reason to disrupt playback.
    }
  }
}
