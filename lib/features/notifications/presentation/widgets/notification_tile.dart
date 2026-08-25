// ignore_for_file: deprecated_member_use

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../domain/entities/notification_item.dart';

class NotificationTile extends StatelessWidget {
  const NotificationTile({super.key, required this.item, required this.onTap});

  final NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      tileColor: item.isRead
          ? null
          : context.colors.primaryContainer.withOpacity(0.25),
      leading: Stack(
        children: [
          CircleAvatar(
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
      ),
      title: Text.rich(
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
      ),
      subtitle: Text(
        _relativeTime(item.createdAt),
        style: context.textTheme.labelSmall,
      ),
      trailing: item.isRead
          ? null
          : Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: context.colors.primary,
                shape: BoxShape.circle,
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
    NotificationKind.commentLike => Colors.pinkAccent,
    NotificationKind.friendRequestAccepted => Colors.green,
    NotificationKind.repost => Colors.teal,
    _ => Colors.blueAccent,
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
