import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../domain/entities/follow_list_item.dart';

class FollowListTile extends StatelessWidget {
  const FollowListTile({
    super.key,
    required this.item,
    required this.avatarUrl,
    required this.isViewerSelf,
    required this.onTap,
    required this.onToggleFollow,
    this.isBusy = false,
  });

  final FollowListItem item;
  final String? avatarUrl;

  /// True when this row *is* the current user — hides the Follow button
  /// (you can't follow yourself).
  final bool isViewerSelf;

  final VoidCallback onTap;
  final VoidCallback onToggleFollow;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: context.colors.surfaceContainerHighest,
        backgroundImage: avatarUrl != null
            ? CachedNetworkImageProvider(avatarUrl!)
            : null,
        child: avatarUrl == null ? const Icon(Icons.person_rounded) : null,
      ),
      title: Text(
        item.profile.fullName.isNotEmpty
            ? item.profile.fullName
            : '@${item.profile.username}',
      ),
      subtitle: Text('@${item.profile.username}'),
      trailing: isViewerSelf
          ? null
          : SizedBox(
              width: 100,
              child: OutlinedButton(
                onPressed: isBusy ? null : onToggleFollow,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(item.isFollowedByViewer ? 'Following' : 'Follow'),
              ),
            ),
    );
  }
}
