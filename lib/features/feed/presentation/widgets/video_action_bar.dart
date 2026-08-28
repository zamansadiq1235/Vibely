import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/video_post.dart';

/// Actions here are display + basic gestures only in this phase. Wiring
/// each icon to its persisted mutation happens as its own feature lands:
/// like -> Phase 7, comment -> Phase 8, share/save/repost -> Phase 9.
class VideoActionBar extends StatelessWidget {
  const VideoActionBar({
    super.key,
    required this.post,
    required this.onLikeTap,
    this.onCommentTap,
    this.onShareTap,
    this.onSaveTap,
    this.onRepostTap,
    this.onAvatarTap,
  });

  final VideoPost post;
  final VoidCallback onLikeTap;
  final VoidCallback? onCommentTap;
  final VoidCallback? onShareTap;
  final VoidCallback? onSaveTap;
  final VoidCallback? onRepostTap;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onAvatarTap,
          child: CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white24,
            backgroundImage: post.avatarUrl != null
                ? CachedNetworkImageProvider(post.avatarUrl!)
                : null,
            child: post.avatarUrl == null
                ? const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 22,
                  )
                : null,
          ),
        ),
        const SizedBox(height: 18),
        _ActionButton(
          icon: post.isLikedByMe
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          iconColor: post.isLikedByMe ? AppColors.secondaryAccent : Colors.white,
          label: _formatCount(post.likesCount),
          onTap: onLikeTap,
        ),
        _ActionButton(
          icon: Icons.chat_bubble_outline_rounded,
          label: _formatCount(post.commentsCount),
          onTap: onCommentTap,
        ),
        _ActionButton(
          icon: Icons.reply_rounded,
          label: _formatCount(post.sharesCount),
          onTap: onShareTap,
        ),
        _ActionButton(
          icon: post.isSavedByMe
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          iconColor: post.isSavedByMe ? AppColors.bookmarkGold : Colors.white,
          label: _formatCount(post.savesCount),
          onTap: onSaveTap,
        ),
        _ActionButton(
          icon: Icons.repeat_rounded,
          iconColor: post.isRepostedByMe ? Colors.greenAccent : Colors.white,
          label: _formatCount(post.repostsCount),
          onTap: onRepostTap,
        ),
      ],
    );
  }

  static String _formatCount(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.iconColor = Colors.white,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Icon(
              icon,
              color: iconColor,
              size: 30,
              shadows: const [Shadow(color: Colors.black45, blurRadius: 6)],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.statCount.copyWith(
                color: Colors.white,
                shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
