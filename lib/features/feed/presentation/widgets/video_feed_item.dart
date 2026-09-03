// ignore_for_file: unnecessary_underscores

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../domain/entities/video_post.dart';
import '../../../upload/domain/entities/video_animation_preset.dart';
import '../../../upload/domain/entities/video_filter_preset.dart';
import 'video_action_bar.dart';
import 'video_caption_overlay.dart';

class VideoFeedItem extends StatefulWidget {
  const VideoFeedItem({
    super.key,
    required this.post,
    required this.controller,
    required this.isActive,
    required this.isMuted,
    required this.onToggleMute,
    required this.onLikeTap,
    required this.onDoubleTapLike,
    this.onPlayPauseToggled,
    required this.onRetry,
    this.onCommentTap,
    this.onShareTap,
    this.onSaveTap,
    this.onRepostTap,
    this.onAvatarTap,
  });

  final VideoPost post;

  /// Null while the controller is still being created/initialized —
  /// the item shows its thumbnail + a buffering spinner in that case.
  final VideoPlayerController? controller;
  final bool isActive;
  final bool isMuted;

  final VoidCallback onToggleMute;
  final VoidCallback onLikeTap;
  final VoidCallback onDoubleTapLike;

  /// Fired whenever the user manually starts/stops playback through the
  /// gesture layer or control row (tap, play/pause button, hold-for-2x).
  /// Lets the feed screen remember a deliberate pause so automatic
  /// resumes (app foregrounding, sheet dismissal) respect it.
  final ValueChanged<bool>? onPlayPauseToggled;
  final VoidCallback onRetry;
  final VoidCallback? onCommentTap;
  final VoidCallback? onShareTap;
  final VoidCallback? onSaveTap;
  final VoidCallback? onRepostTap;
  final VoidCallback? onAvatarTap;

  @override
  State<VideoFeedItem> createState() => _VideoFeedItemState();
}

class _VideoFeedItemState extends State<VideoFeedItem>
    with TickerProviderStateMixin {
  // ---------- Playback controls ----------
  static const int _skipSeconds = 5;
  static const double _fastForwardSpeed = 2.0;
  static const Duration _seekFeedbackVisibleFor = Duration(milliseconds: 700);

  // Hold-screen-for-2x state.
  bool _isHoldingFast = false;
  bool _wasPlayingBeforeHold = false;
  double _speedBeforeHold = 1.0;

  // Sequential-seeking bookkeeping: position lags behind issued seeks, so
  // base follow-up skips on the last requested target instead. Null once
  // the latest seek lands.
  Duration? _pendingSeekTarget;

  // Transient "±5s" feedback chip shown after a skip.
  Timer? _seekFeedbackTimer;
  int? _seekFeedbackSeconds;

  // Mirrored controller flags so we only rebuild the overlay layer when
  // something visible actually changed (the listener fires often).
  bool? _cachedIsPlaying;
  bool? _cachedIsBuffering;
  bool? _cachedHasError;

  late final AnimationController _heartAnim;
  AnimationController? _animController;
  bool _showHeartPop = false;

  @override
  void initState() {
    super.initState();
    _heartAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _syncAnimationPreset();
    widget.controller?.addListener(_onControllerTick);
  }

  @override
  void didUpdateWidget(covariant VideoFeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      try {
        oldWidget.controller?.removeListener(_onControllerTick);
      } catch (_) {
        // Old controller may already be disposed by the feed cache.
      }
      widget.controller?.addListener(_onControllerTick);
      // A fresh controller doesn't carry over an in-progress hold.
      _isHoldingFast = false;
      _pendingSeekTarget = null;
      _seekFeedbackTimer?.cancel();
      _seekFeedbackSeconds = null;
    }
    _syncAnimationPreset();
  }

  /// Keeps the overlay layer (center play arrow, control-row icon) honest
  /// about playback state regardless of who moved it: user taps, autoplay
  /// on ready, app backgrounding, or buffering churn.
  void _onControllerTick() {
    if (!mounted) return;
    final controller = widget.controller;
    if (controller == null || !controller.value.isInitialized) return;
    final value = controller.value;
    if (value.isPlaying != _cachedIsPlaying ||
        value.isBuffering != _cachedIsBuffering ||
        value.hasError != _cachedHasError) {
      setState(() {
        _cachedIsPlaying = value.isPlaying;
        _cachedIsBuffering = value.isBuffering;
        _cachedHasError = value.hasError;
      });
    }
  }

  @override
  void dispose() {
    _seekFeedbackTimer?.cancel();
    // Restore anything an in-flight hold changed — e.g. the item scrolled
    // away and unmounted mid-hold — best effort, since the controller may
    // already be disposed by the feed's controller cache.
    if (_isHoldingFast) {
      final controller = widget.controller;
      try {
        controller?.setPlaybackSpeed(_speedBeforeHold);
        if (!_wasPlayingBeforeHold) controller?.pause();
      } catch (_) {}
      _isHoldingFast = false;
    }
    try {
      widget.controller?.removeListener(_onControllerTick);
    } catch (_) {}
    _heartAnim.dispose();
    _animController?.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    widget.onDoubleTapLike();
    setState(() => _showHeartPop = true);
    _heartAnim.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _showHeartPop = false);
    });
  }

  /// Single tap anywhere on the video toggles between paused and playing.
  /// Pausing stops playback completely until the user plays again — that
  /// paused intent is reported upstream so automatic resumes honor it.
  void _handleTogglePlayPause() {
    final controller = widget.controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (_isHoldingFast) return; // an in-progress hold owns the transport

    final willPlay = !controller.value.isPlaying;
    if (willPlay) {
      controller.setPlaybackSpeed(1.0);
      controller.play();
    } else {
      controller.pause();
    }
    setState(() {});
    widget.onPlayPauseToggled?.call(willPlay);
  }

  /// Press-and-hold anywhere on the screen: play at 2x speed. On release,
  /// restore exactly what was happening before (previous speed, and back
  /// to paused if the video had been paused).
  void _handleHoldStart(LongPressStartDetails _) {
    final controller = widget.controller;
    if (controller == null || !controller.value.isInitialized) return;

    _wasPlayingBeforeHold = controller.value.isPlaying;
    _speedBeforeHold = controller.value.playbackSpeed == _fastForwardSpeed
        ? 1.0
        : controller.value.playbackSpeed;
    _isHoldingFast = true;

    HapticFeedback.mediumImpact();
    controller.setPlaybackSpeed(_fastForwardSpeed);
    if (!_wasPlayingBeforeHold) controller.play();
    setState(() {});
    if (!_wasPlayingBeforeHold) widget.onPlayPauseToggled?.call(true);
  }

  void _handleHoldEnd(LongPressEndDetails _) => _endFastHold();

  void _handleHoldCancel() => _endFastHold();

  void _endFastHold() {
    if (!_isHoldingFast) return;
    _isHoldingFast = false;

    final controller = widget.controller;
    if (controller != null &&
        controller.value.isInitialized &&
        !controller.value.hasError) {
      controller.setPlaybackSpeed(_speedBeforeHold);
      if (!_wasPlayingBeforeHold) {
        controller.pause();
        widget.onPlayPauseToggled?.call(false);
      }
    }
    setState(() {});
  }

  /// Skips forward/backward by [_skipSeconds]. Rapid taps accumulate off
  /// the last requested target because the reported position lags behind
  /// issued seeks.
  Future<void> _handleSkip(int seconds) async {
    final controller = widget.controller;
    if (controller == null || !controller.value.isInitialized) return;
    final duration = controller.value.duration;
    if (duration <= Duration.zero) return;

    final base = _pendingSeekTarget ?? controller.value.position;
    var target = base + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (target >= duration) {
      target = duration - const Duration(milliseconds: 50);
    }

    _pendingSeekTarget = target;
    HapticFeedback.selectionClick();
    try {
      await controller.seekTo(target);
    } catch (_) {
      // Item may have been torn down mid-seek.
    }
    if (_pendingSeekTarget == target) _pendingSeekTarget = null;

    _flashSeekFeedback(seconds);
  }

  /// Briefly flashes a "±Ns" chip so the skip is visible feedback.
  void _flashSeekFeedback(int seconds) {
    _seekFeedbackTimer?.cancel();
    setState(() => _seekFeedbackSeconds = seconds);
    _seekFeedbackTimer = Timer(_seekFeedbackVisibleFor, () {
      if (!mounted) return;
      setState(() => _seekFeedbackSeconds = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final ready = controller != null && controller.value.isInitialized;
    final hasError = controller != null && controller.value.hasError;

    return GestureDetector(
      onTap: _handleTogglePlayPause,
      onDoubleTap: _handleDoubleTap,
      // Hold anywhere on the screen: play at 2x until released.
      onLongPressStart: _handleHoldStart,
      onLongPressEnd: _handleHoldEnd,
      onLongPressCancel: _handleHoldCancel,
      behavior: HitTestBehavior.deferToChild,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail — shown until the real video is ready, and stays
            // underneath it as a safety net if playback ever errors.
            if (widget.post.thumbnailUrl != null)
              CachedNetworkImage(
                imageUrl: widget.post.thumbnailUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),

            if (ready)
              Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  // Re-applies the color grade picked in the composer's Filter
                  // step and drives the motion preset chosen in the Animations
                  // rail the same way.
                  child: _applyAnimation(
                    t: _animController?.value ?? 0,
                    child: _applyFilter(child: VideoPlayer(controller)),
                  ),
                ),
              ),

            if (hasError) _ErrorState(onRetry: widget.onRetry),

            if (!ready && !hasError)
              const Center(
                child: CircularProgressIndicator(color: Colors.white70),
              ),

            if (ready && controller.value.isBuffering)
              const Center(
                child: CircularProgressIndicator(color: Colors.white70),
              ),

            if (ready &&
                !controller.value.isPlaying &&
                !controller.value.isBuffering)
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Back $_skipSeconds seconds',
                      onPressed: () => _handleSkip(-_skipSeconds),
                      icon: const Icon(
                        Icons.replay_5_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.play_arrow_rounded,
                      size: 72,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      tooltip: 'Forward $_skipSeconds seconds',
                      onPressed: () => _handleSkip(_skipSeconds),
                      icon: Icon(
                        Icons.forward_5_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ],
                ),
              ),

            // Double-tap heart pop, backed by a persisted like/unlike
            // with optimistic UI + rollback (LikeActions, Phase 7).
            if (_showHeartPop)
              Center(
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.6, end: 1.3).animate(
                    CurvedAnimation(
                      parent: _heartAnim,
                      curve: Curves.elasticOut,
                    ),
                  ),
                  child: FadeTransition(
                    opacity: Tween<double>(begin: 1, end: 0).animate(
                      CurvedAnimation(
                        parent: _heartAnim,
                        curve: const Interval(0.6, 1.0),
                      ),
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                      size: 120,
                    ),
                  ),
                ),
              ),

            // Hold-for-2x badge
            if (_isHoldingFast) _buildSpeedBadge(),

            // Transient ±5s skip feedback chip
            if (_seekFeedbackSeconds != null) _buildSeekFlashChip(),

            // Mute toggle
            Positioned(
              top: 8,
              right: 8,
              child: SafeArea(
                child: IconButton(
                  icon: Icon(
                    widget.isMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: Colors.white,
                    shadows: const [
                      Shadow(color: Colors.black45, blurRadius: 6),
                    ],
                  ),
                  onPressed: widget.onToggleMute,
                ),
              ),
            ),

            // Action bar + caption
            Positioned(
              right: 8,
              bottom: 30,
              child: VideoActionBar(
                post: widget.post,
                onLikeTap: widget.onLikeTap,
                onCommentTap: widget.onCommentTap,
                onShareTap: widget.onShareTap,
                onSaveTap: widget.onSaveTap,
                onRepostTap: widget.onRepostTap,
                onAvatarTap: widget.onAvatarTap,
              ),
            ),
            Positioned(
              left: 16,
              right: 88,
              bottom: 30,
              child: VideoCaptionOverlay(post: widget.post),
            ),

            // Background-music badge (track chosen in the composer's Music step).
            if (widget.post.musicTitle != null)
              Positioned(
                top: 8,
                left: 8,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.music_note_rounded, color: Colors.white, size: 12),
                        const SizedBox(width: 5),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: Text(
                            widget.post.musicTitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Progress bar
            if (ready)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: VideoProgressIndicator(
                  controller,
                  allowScrubbing: true,
                  padding: EdgeInsets.zero,
                  colors: const VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Colors.white30,
                    backgroundColor: Colors.white10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------- Overlay widgets ----------

  /// Drives the composer's chosen motion preset with a looping AnimationController
  /// (same metadata-only pattern as the filter re-application below). The
  /// controller is recycled whenever the post's `animation_preset` changes.

  void _syncAnimationPreset() {
    final preset = VideoAnimationPreset.byId(widget.post.animationPresetId);
    if (preset == null || preset.kind == VideoAnimationKind.none) {
      _animController?.dispose();
      _animController = null;
      return;
    }
    if (_animController != null && _animController!.duration == preset.duration) {
      if (!_animController!.isAnimating) _animController!.repeat();
      return;
    }
    _animController?.dispose();
    final anim = AnimationController(vsync: this, duration: preset.duration);
    _animController = anim;
    anim.repeat();
  }

  /// Wraps [child] (the filtered video) with the post's motion preset at the
  /// current loop position. Touches nothing when the post has no animation.

  Widget _applyAnimation({required Widget child, required double t}) {
    final preset = VideoAnimationPreset.byId(widget.post.animationPresetId);
    if (preset == null || preset.id == VideoAnimationPreset.none.id || _animController == null) {
      return child;
    }
    return preset.wrap(child: child, t: t);
  }

  /// Wraps [child] in the post's saved color-grade matrix when it has
  /// one; returns the child untouched for original/no-filter uploads.
  Widget _applyFilter({required Widget child}) {
    final preset = VideoFilterPreset.byId(widget.post.filterPresetId);
    if (preset == null || preset.id == VideoFilterPreset.none.id) {
      return child;
    }
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(preset.matrix),
      child: child,
    );
  }

  Widget _buildSpeedBadge() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fast_forward_rounded, color: Colors.white, size: 20),
                SizedBox(width: 6),
                Text(
                  '2x',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeekFlashChip() {
    final seconds = _seekFeedbackSeconds!;
    final isBackward = seconds < 0;
    return Center(
      child: Container(
        key: ValueKey<int>(seconds),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isBackward ? Icons.replay_5_rounded : Icons.forward_5_rounded,
              color: Colors.white,
              size: 26,
            ),
            const SizedBox(width: 8),
            Text(
              '${isBackward ? '-' : '+'}${seconds.abs()}s',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.white70,
            size: 40,
          ),
          const SizedBox(height: 8),
          const Text(
            'Couldn\'t play this video',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
