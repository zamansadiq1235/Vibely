import 'package:flutter/material.dart';

import '../../domain/entities/relationship_info.dart';

class ProfileActionButtons extends StatelessWidget {
  const ProfileActionButtons({
    super.key,
    required this.isOwnProfile,
    required this.relationship,
    required this.isBusy,
    this.onEditProfile,
    this.onToggleFollow,
    this.onSendFriendRequest,
    this.onCancelFriendRequest,
    this.onAcceptFriendRequest,
    this.onRemoveFriend,
  });

  final bool isOwnProfile;
  final RelationshipInfo relationship;
  final bool isBusy;

  final VoidCallback? onEditProfile;
  final VoidCallback? onToggleFollow;
  final VoidCallback? onSendFriendRequest;
  final VoidCallback? onCancelFriendRequest;
  final VoidCallback? onAcceptFriendRequest;
  final VoidCallback? onRemoveFriend;

  @override
  Widget build(BuildContext context) {
    if (isOwnProfile) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onEditProfile,
          child: const Text('Edit Profile'),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: isBusy ? null : onToggleFollow,
            child: Text(relationship.isFollowing ? 'Following' : 'Follow'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: _friendButton(context)),
      ],
    );
  }

  Widget _friendButton(BuildContext context) {
    switch (relationship.friendStatus) {
      case FriendStatus.none:
        return OutlinedButton(
          onPressed: isBusy ? null : onSendFriendRequest,
          child: const Text('Add Friend'),
        );
      case FriendStatus.requestSentByMe:
        return OutlinedButton(
          onPressed: isBusy ? null : onCancelFriendRequest,
          child: const Text('Request Sent'),
        );
      case FriendStatus.requestReceivedByMe:
        return OutlinedButton(
          onPressed: isBusy ? null : onAcceptFriendRequest,
          child: const Text('Accept'),
        );
      case FriendStatus.friends:
        return OutlinedButton(
          onPressed: isBusy ? null : onRemoveFriend,
          child: const Text('Friends'),
        );
    }
  }
}
