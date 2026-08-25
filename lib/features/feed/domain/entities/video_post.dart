/// A single feed item — a `videos` row joined with its author's profile,
/// with storage paths already resolved to public URLs so the UI layer
/// never touches Supabase directly.
class VideoPost {
  const VideoPost({
    required this.id,
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.caption,
    required this.viewsCount,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.savesCount,
    required this.repostsCount,
    required this.isLikedByMe,
    this.isSavedByMe = false,
    this.isRepostedByMe = false,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String username;
  final String? avatarUrl;
  final String videoUrl;
  final String? thumbnailUrl;
  final String caption;

  final int viewsCount;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final int savesCount;
  final int repostsCount;

  /// Not yet wired to a mutation this phase — Phase 7 (Likes) adds the
  /// toggle. Feed item UI reads this to decide the heart icon's initial
  /// fill state and the double-tap animation's starting point.
  final bool isLikedByMe;

  final bool isSavedByMe;
  final bool isRepostedByMe;

  final DateTime createdAt;

  VideoPost copyWith({
    int? likesCount,
    bool? isLikedByMe,
    int? commentsCount,
    int? savesCount,
    bool? isSavedByMe,
    int? repostsCount,
    bool? isRepostedByMe,
    int? sharesCount,
  }) {
    return VideoPost(
      id: id,
      userId: userId,
      username: username,
      avatarUrl: avatarUrl,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      caption: caption,
      viewsCount: viewsCount,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      savesCount: savesCount ?? this.savesCount,
      repostsCount: repostsCount ?? this.repostsCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      isSavedByMe: isSavedByMe ?? this.isSavedByMe,
      isRepostedByMe: isRepostedByMe ?? this.isRepostedByMe,
      createdAt: createdAt,
    );
  }
}
