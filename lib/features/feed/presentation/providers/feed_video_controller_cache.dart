import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Implements the controller strategy the spec calls out repeatedly
/// (§7, §30): only Previous/Current/Next controllers exist at once.
/// Owned by the feed screen's State (not Riverpod) because
/// VideoPlayerControllers are disposable resources tightly bound to
/// that screen's lifecycle — a Riverpod provider holding them would
/// outlive/underlive the widget in ways that are easy to get wrong.
class FeedVideoControllerCache {
  final Map<int, VideoPlayerController> _controllers = {};
  final Map<int, Future<void>> _initializing = {};

  VideoPlayerController? controllerAt(int index) => _controllers[index];

  bool isReady(int index) => _controllers[index]?.value.isInitialized ?? false;

  /// Creates (if needed) and initializes the controller for [index].
  /// Safe to call repeatedly — concurrent calls for the same index
  /// share the same in-flight initialization future.
  Future<VideoPlayerController> ensure(int index, String url) {
    final existing = _controllers[index];
    if (existing != null) return Future.value(existing);

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controllers[index] = controller;

    final future = controller
        .initialize()
        .then((_) {
          controller.setLooping(true);
        })
        .catchError((_) {
          // Swallow here — VideoFeedItem checks controller.value.hasError
          // and renders its own retry UI; we don't want an unhandled
          // rejection tearing down the whole cache.
        });
    _initializing[index] = future;
    return future.then((_) => controller);
  }

  /// Disposes every controller whose index isn't in [keep] — called on
  /// every page change so at most 3 controllers ever exist together.
  void trimTo(Set<int> keep) {
    final toRemove = _controllers.keys.where((k) => !keep.contains(k)).toList();
    for (final k in toRemove) {
      _controllers.remove(k)?.dispose();
      _initializing.remove(k);
    }
  }

  void pauseAllExcept(int index) {
    for (final entry in _controllers.entries) {
      if (entry.key != index && entry.value.value.isInitialized) {
        entry.value.pause();
      }
    }
  }

  void disposeAll() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    _initializing.clear();
  }

  @visibleForTesting
  int get activeCount => _controllers.length;
}
