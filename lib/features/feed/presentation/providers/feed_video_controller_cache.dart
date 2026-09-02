import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Implements the controller strategy the spec calls out repeatedly
/// (Section 7, Section 30): only Previous/Current/Next controllers exist at once.
/// Owned by the feed screen's State (not Riverpod) because
/// VideoPlayerControllers are disposable resources tightly bound to
/// that screen's lifecycle - a Riverpod provider holding them would
/// outlive/underlive the widget in ways that are easy to get wrong.
///
/// Each index can also carry an optional companion *music* controller that
/// streams the background track picked in the upload composer (same
/// video_player machinery - audio-only files initialize fine). Music
/// controllers obey the same 3-at-a-time window as video controllers.

class FeedVideoControllerCache {
  final Map<int, VideoPlayerController> _controllers = {};
  final Map<int, VideoPlayerController> _musicControllers = {};
  final Map<int, Future<void>> _initializing = {};
  final Map<int, Future<void>> _musicInitializing = {};

  VideoPlayerController? controllerAt(int index) => _controllers[index];
  VideoPlayerController? musicControllerAt(int index) => _musicControllers[index];

  bool isReady(int index) => _controllers[index]?.value.isInitialized ?? false;

  /// Creates (if needed) and initializes the video controller for [index].
  /// Safe to call repeatedly - concurrent calls for the same index
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
          // Swallow here - VideoFeedItem checks controller.value.hasError
          // and renders its own retry UI; we don't want an unhandled
          // rejection tearing down the whole cache.
        });
    _initializing[index] = future;
    return future.then((_) => controller);
  }

  /// Creates (if needed) and initializes the audio-only music controller for
  /// [index], pre-set to the volume the composer chose (or the global mute
  /// override when the user muted everything).
  Future<VideoPlayerController> ensureMusic(int index, String url, {double volume = 1}) {
    final existing = _musicControllers[index];
    if (existing != null) {
      existing.setVolume(volume.clamp(0.0, 1.0));
      return Future.value(existing);
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _musicControllers[index] = controller;

    final future = controller
        .initialize()
        .then((_) {
          controller.setLooping(true);
          controller.setVolume(volume.clamp(0.0, 1.0));
        })
        .catchError((_) {
          // Music is an enhancement - a failed track must never break the
          // feed; the video simply plays without background audio.

        });
    _musicInitializing[index] = future;
    return future.then((_) => controller);
  }

  void setMusicVolume(int index, double volume) =>
      _musicControllers[index]?.setVolume(volume.clamp(0.0, 1.0));

  void playMusic(int index) {
    final c = _musicControllers[index];
    if (c != null && c.value.isInitialized && !c.value.hasError) c.play();
  }

  void pauseMusic(int index) => _musicControllers[index]?.pause();

  /// Disposes every controller whose index isn't in [keep] - called on
  /// every page change so at most 3 video+music controller pairs ever
  /// exist together.


  void trimTo(Set<int> keep) {
    final toRemove = _controllers.keys.where((k) => !keep.contains(k)).toList();
    for (final k in toRemove) {
      _controllers.remove(k)?.dispose();
      _initializing.remove(k);
    }
    final musicToRemove =
        _musicControllers.keys.where((k) => !keep.contains(k)).toList();
    for (final k in musicToRemove) {
      _musicControllers.remove(k)?.dispose();
      _musicInitializing.remove(k);
    }
  }

  void pauseAllExcept(int index) {
    for (final entry in _controllers.entries) {
      if (entry.key != index && entry.value.value.isInitialized) {
        entry.value.pause();
      }
    }
    for (final entry in _musicControllers.entries) {
      if (entry.key != index && entry.value.value.isInitialized) {
        entry.value.pause();
      }
    }
  }

  void disposeAll() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final c in _musicControllers.values) {
      c.dispose();
    }
    _controllers.clear();
    _musicControllers.clear();
    _initializing.clear();
    _musicInitializing.clear();
  }

  @visibleForTesting
  int get activeCount => _controllers.length + _musicControllers.length;
}