import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/notification_item.dart';

class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.item,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.selectionMode = false,
  });

  final NotificationItem item;
  final VoidCallback onTap;

  /// Starts multi-select mode from this tile.
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool selectionMode;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final isDark = context.isDark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Material(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.18)
            : item.isRead
            ? theme.colorScheme.surface.withValues(alpha: 0.4)
            : AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : isDark
                    ? Colors.white12
                    : Colors.black.withValues(alpha: 0.05),
                width: isSelected ? 1.2 : 1,
              ),
            ),
            child: Row(
              children: [
                _buildLeading(context),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '@${item.actorUsername} ',
                              style: context.textTheme.bodyLarge,
                            ),
                            TextSpan(
                              text: _messageFor(item.kind),
                              style: context.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _relativeTime(item.createdAt),
                        style: context.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                if (!selectionMode && !item.isRead) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Leading slot: an avatar normally, and an animated checkbox that
  /// cross-fades in whenever multi-select mode is active.
  Widget _buildLeading(BuildContext context) {
    final avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: context.colors.surfaceContainerHighest,
          backgroundImage: item.actorAvatarUrl != null
              ? CachedNetworkImageProvider(item.actorAvatarUrl!)
              : null,
          child: item.actorAvatarUrl == null
              ? const Icon(Icons.person_rounded)
              : null,
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: context.theme.scaffoldBackgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _iconFor(item.kind),
              size: 14,
              color: _colorFor(item.kind),
            ),
          ),
        ),
      ],
    );

    if (!selectionMode) return avatar;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: child),
      child: AnimatedContainer(
        key: ValueKey(isSelected),
        width: 44,
        height: 44,
        alignment: Alignment.center,
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? AppColors.primary : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppColors.primary : context.colors.outline,
            width: 2,
          ),
        ),
        child: isSelected
            ? const Icon(Icons.check_rounded, size: 24, color: Colors.white)
            : Icon(
                Icons.circle_outlined,
                size: 20,
                color: context.colors.outline,
              ),
      ),
    );
  }

  static IconData _iconFor(NotificationKind kind) => switch (kind) {
    NotificationKind.videoLike ||
    NotificationKind.commentLike => Icons.favorite_rounded,
    NotificationKind.comment => Icons.chat_bubble_rounded,
    NotificationKind.commentReply => Icons.reply_rounded,
    NotificationKind.newFollower => Icons.person_add_rounded,
    NotificationKind.friendRequest => Icons.person_add_alt_1_rounded,
    NotificationKind.friendRequestAccepted => Icons.check_circle_rounded,
    NotificationKind.repost => Icons.repeat_rounded,
  };

  static Color _colorFor(NotificationKind kind) => switch (kind) {
    NotificationKind.videoLike ||
    NotificationKind.commentLike => AppColors.secondaryAccent,
    NotificationKind.friendRequestAccepted => AppColors.success,
    NotificationKind.repost => AppColors.accent,
    _ => AppColors.primary,
  };

  static String _messageFor(NotificationKind kind) => switch (kind) {
    NotificationKind.videoLike => 'liked your video',
    NotificationKind.comment => 'commented on your video',
    NotificationKind.commentLike => 'liked your comment',
    NotificationKind.commentReply => 'replied to your comment',
    NotificationKind.newFollower => 'followed you',
    NotificationKind.friendRequest => 'sent you a friend request',
    NotificationKind.friendRequestAccepted => 'accepted your friend request',
    NotificationKind.repost => 'reposted your video',
  };

  static String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat.MMMd().format(dt);
  }
}
