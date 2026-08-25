/// Friend relationship between the current user and a viewed profile.
/// Mirrors the `friend_requests.status` enum but from the current
/// user's point of view (who sent it matters for which buttons to show).
enum FriendStatus { none, requestSentByMe, requestReceivedByMe, friends }

/// Everything the Profile screen needs to decide which action buttons
/// to show for someone else's profile (Follow/Unfollow, Add Friend/
/// Request Sent/Accept/Friends).
class RelationshipInfo {
  const RelationshipInfo({
    required this.isFollowing,
    required this.friendStatus,
    this.friendRequestId,
  });

  final bool isFollowing;
  final FriendStatus friendStatus;

  /// Needed to cancel/accept/reject a specific pending request.
  final String? friendRequestId;

  static const none = RelationshipInfo(
    isFollowing: false,
    friendStatus: FriendStatus.none,
  );
}
