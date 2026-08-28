import 'package:flutter/material.dart';

import '../../domain/entities/video_post.dart';

class VideoCaptionOverlay extends StatelessWidget {
  const VideoCaptionOverlay({super.key, required this.post});

  final VideoPost post;

  @override
  Widget build(BuildContext context) {
    const shadow = [Shadow(color: Colors.black54, blurRadius: 6)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '@${post.username}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15,
            shadows: shadow,
          ),
        ),
        if (post.musicTitle != null) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.music_note_rounded,
                color: Colors.white70,
                size: 13,
                shadows: shadow,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  post.musicTitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    shadows: shadow,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (post.caption.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            post.caption,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              shadows: shadow,
            ),
          ),
        ],
      ],
    );
  }
}
