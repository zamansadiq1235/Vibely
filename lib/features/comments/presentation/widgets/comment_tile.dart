import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/comment.dart';

class CommentTile extends StatelessWidget {
  const CommentTile({
    super.key,
    required this.comment,
    required this.onLikeTap,
    required this.onReplyTap,
    this.onDeleteTap,
    this.isIndented = false,
    this.repliesExpanded = false,
    this.onToggleReplies,
  });

  final Comment comment;
  final VoidCallback onLikeTap;
  final VoidCallback onReplyTap;
  final VoidCallback? onDeleteTap;
  final bool isIndented;
  final bool repliesExpanded;
  final VoidCallback? onToggleReplies;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: isIndented ? 44 : 0, top: 14, right: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: isIndented ? 14 : 17,
            backgroundColor: context.colors.surfaceContainerHighest,
            backgroundImage: comment.avatarUrl != null
                ? CachedNetworkImageProvider(comment.avatarUrl!)
                : null,
            child: comment.avatarUrl == null
                ? Icon(Icons.person_rounded, size: isIndented ? 14 : 18)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '@${comment.username}',
                      style: context.textTheme.bodyLarge,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _relativeTime(comment.createdAt),
                      style: context.textTheme.labelSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(comment.content, style: context.textTheme.bodyMedium),
                const SizedBox(height: 6),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onReplyTap,
                      child: Text('Reply', style: context.textTheme.labelSmall),
                    ),
                    if (!isIndented && comment.repliesCount > 0) ...[
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: onToggleReplies,
                        child: Row(
                          children: [
                            Icon(
                              repliesExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: context.colors.outline,
                            ),
                            Text(
                              repliesExpanded
                                  ? 'Hide replies'
                                  : '${comment.repliesCount} ${comment.repliesCount == 1 ? 'Reply' : 'Replies'}',
                              style: context.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              GestureDetector(
                onTap: onLikeTap,
                child: Icon(
                  comment.isLikedByMe
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 18,
                  color: comment.isLikedByMe
                      ? AppColors.secondaryAccent
                      : context.colors.outline,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${comment.likesCount}',
                style: context.textTheme.labelSmall,
              ),
            ],
          ),
          if (comment.isMine && onDeleteTap != null)
            IconButton(
              icon: const Icon(Icons.more_horiz_rounded, size: 18),
              visualDensity: VisualDensity.compact,
              onPressed: () => _confirmDelete(context),
            ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListTile(
          leading: Icon(
            Icons.delete_outline_rounded,
            color: context.colors.error,
          ),
          title: Text(
            'Delete comment',
            style: TextStyle(color: context.colors.error),
          ),
          onTap: () {
            Navigator.of(sheetContext).pop();
            onDeleteTap?.call();
          },
        ),
      ),
    );
  }

  static String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat.MMMd().format(dt);
  }
}
