/// A `comments` row joined with its author's profile. Top-level comments
/// have `parentId == null`; replies carry the id of the comment they
/// reply to (spec §13). The UI keeps this to two visual levels — a
/// reply's "Reply" action still targets the *top-level* comment's id,
/// even though the schema itself supports arbitrary nesting — matching
/// how most short-video apps flatten threads for readability.
class Comment {
  const Comment({
    required this.id,
    required this.videoId,
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.parentId,
    required this.content,
    required this.likesCount,
    required this.repliesCount,
    required this.isLikedByMe,
    required this.isMine,
    required this.createdAt,
  });

  final String id;
  final String videoId;
  final String userId;
  final String username;
  final String? avatarUrl;
  final String? parentId;
  final String content;
  final int likesCount;
  final int repliesCount;
  final bool isLikedByMe;
  final bool isMine;
  final DateTime createdAt;

  bool get isReply => parentId != null;

  Comment copyWith({int? likesCount, int? repliesCount, bool? isLikedByMe}) {
    return Comment(
      id: id,
      videoId: videoId,
      userId: userId,
      username: username,
      avatarUrl: avatarUrl,
      parentId: parentId,
      content: content,
      likesCount: likesCount ?? this.likesCount,
      repliesCount: repliesCount ?? this.repliesCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      isMine: isMine,
      createdAt: createdAt,
    );
  }
}
