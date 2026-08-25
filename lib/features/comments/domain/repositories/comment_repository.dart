import '../entities/comment.dart';

abstract class CommentRepository {
  /// Top-level comments only (`parent_id IS NULL`), newest first, paged.
  Future<List<Comment>> fetchComments({
    required String videoId,
    required int page,
  });

  /// Replies to [parentId], oldest first, paged.
  Future<List<Comment>> fetchReplies({
    required String parentId,
    required int page,
  });

  Future<Comment> addComment({
    required String videoId,
    required String content,
    String? parentId,
  });

  Future<void> deleteComment(String commentId);

  Future<void> likeComment(String commentId);
  Future<void> unlikeComment(String commentId);
}
