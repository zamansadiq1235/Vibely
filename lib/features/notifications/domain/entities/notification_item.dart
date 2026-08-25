/// Mirrors the `notification_type` Postgres enum (migration 0001)
/// exactly, so mapping a raw row's `type` string here is a 1:1 lookup.
enum NotificationKind {
  videoLike,
  comment,
  commentLike,
  commentReply,
  newFollower,
  friendRequest,
  friendRequestAccepted,
  repost;

  static NotificationKind fromDb(String value) => switch (value) {
    'video_like' || 'like_video' => NotificationKind.videoLike,
    'comment' || 'comment_video' => NotificationKind.comment,
    'comment_like' || 'like_comment' => NotificationKind.commentLike,
    'comment_reply' || 'reply_comment' => NotificationKind.commentReply,
    'new_follower' || 'follow' => NotificationKind.newFollower,
    'friend_request' ||
    'friend_request_received' => NotificationKind.friendRequest,
    'friend_request_accepted' => NotificationKind.friendRequestAccepted,
    'repost' || 'repost_video' => NotificationKind.repost,
    _ => NotificationKind.videoLike,
  };
}

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.kind,
    required this.actorId,
    required this.actorUsername,
    this.actorAvatarUrl,
    this.videoId,
    this.commentId,
    this.friendRequestId,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final NotificationKind kind;

  final String actorId;
  final String actorUsername;
  final String? actorAvatarUrl;

  final String? videoId;
  final String? commentId;
  final String? friendRequestId;

  final bool isRead;
  final DateTime createdAt;

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      id: id,
      kind: kind,
      actorId: actorId,
      actorUsername: actorUsername,
      actorAvatarUrl: actorAvatarUrl,
      videoId: videoId,
      commentId: commentId,
      friendRequestId: friendRequestId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}
