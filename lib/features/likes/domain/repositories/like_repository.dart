abstract class LikeRepository {
  /// Idempotent: liking an already-liked video or unliking an
  /// already-unliked one succeeds silently rather than throwing, since
  /// the caller (optimistic UI) may retry after a race with itself.
  Future<void> likeVideo(String videoId);
  Future<void> unlikeVideo(String videoId);
}
