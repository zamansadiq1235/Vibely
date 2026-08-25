// ignore_for_file: unnecessary_underscores

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../features/feed/domain/entities/video_post.dart';

/// Spec §5/§15/§16 all call for "a responsive grid" of video thumbnails
/// on the Profile tabs and the dedicated Saved/Reposted/Liked screens —
/// this is that one grid, reused everywhere it's needed.
///
/// Tapping a thumbnail is a no-op beyond [onTap] right now: there's no
/// standalone single-video player screen yet (spec §41 lists one
/// separately from the main feed), so callers pass a lightweight hint
/// (e.g. a snackbar) rather than a real navigation until that screen
/// exists.
class VideoThumbnailGrid extends StatelessWidget {
  const VideoThumbnailGrid({
    super.key,
    required this.videos,
    required this.onTap,
    this.crossAxisCount = 3,
  });

  final List<VideoPost> videos;
  final void Function(VideoPost) onTap;
  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      itemCount: videos.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        childAspectRatio: 9 / 16,
      ),
      itemBuilder: (context, index) {
        final video = videos[index];
        return GestureDetector(
          onTap: () => onTap(video),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (video.thumbnailUrl != null)
                CachedNetworkImage(
                  imageUrl: video.thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(color: Colors.black26),
                )
              else
                Container(
                  color: context.colors.surfaceContainerHighest,
                  child: const Icon(Icons.play_circle_outline_rounded),
                ),
              Positioned(
                left: 4,
                bottom: 4,
                child: Row(
                  children: [
                    const Icon(
                      Icons.play_arrow_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    Text(
                      _formatCount(video.viewsCount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _formatCount(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }
}
