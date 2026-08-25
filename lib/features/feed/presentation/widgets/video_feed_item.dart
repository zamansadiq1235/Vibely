// ignore_for_file: unnecessary_underscores

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../domain/entities/video_post.dart';
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _heartAnim;
  bool _showHeartPop = false;

  @override
  void initState() {
    super.initState();
    _heartAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _heartAnim.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    widget.onDoubleTapLike();
    setState(() => _showHeartPop = true);
    _heartAnim.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _showHeartPop = false);
    });
  }

  void _handleTap() {
    final controller = widget.controller;
    if (controller == null || !controller.value.isInitialized) return;
    controller.value.isPlaying ? controller.pause() : controller.play();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final ready = controller != null && controller.value.isInitialized;
    final hasError = controller != null && controller.value.hasError;

    return GestureDetector(
      onTap: _handleTap,
      onDoubleTap: _handleDoubleTap,
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
                  child: VideoPlayer(controller),
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
              const Center(
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 72,
                  color: Colors.white70,
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
