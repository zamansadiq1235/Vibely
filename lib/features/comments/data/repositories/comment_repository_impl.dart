import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/comment.dart';
import '../../domain/repositories/comment_repository.dart';
import '../datasources/comment_remote_data_source.dart';

class CommentRepositoryImpl implements CommentRepository {
  CommentRepositoryImpl(this._dataSource, this._client);

  final CommentRemoteDataSource _dataSource;
  final SupabaseClient _client;

  Comment _toEntity(Map<String, dynamic> row, Set<String> likedIds) {
    final author = row['profiles'] as Map<String, dynamic>?;
    final myId = _client.auth.currentUser?.id;
    return Comment(
      id: row['id'] as String,
      videoId: row['video_id'] as String,
      userId: row['user_id'] as String,
      username: author?['username'] as String? ?? 'unknown',
      avatarUrl: _dataSource.resolveAvatarUrl(
        author?['avatar_path'] as String?,
      ),
      parentId: row['parent_id'] as String?,
      content: row['content'] as String,
      likesCount: (row['likes_count'] as int?) ?? 0,
      repliesCount: (row['replies_count'] as int?) ?? 0,
      isLikedByMe: likedIds.contains(row['id']),
      isMine: row['user_id'] == myId,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  @override
  Future<List<Comment>> fetchComments({
    required String videoId,
    required int page,
  }) async {
    final rows = await _dataSource.fetchCommentRows(
      videoId: videoId,
      page: page,
    );
    if (rows.isEmpty) return [];
    final likedIds = await _dataSource.fetchLikedCommentIds(
      rows.map((r) => r['id'] as String).toList(),
    );
    return rows.map((r) => _toEntity(r, likedIds)).toList();
  }

  @override
  Future<List<Comment>> fetchReplies({
    required String parentId,
    required int page,
  }) async {
    final rows = await _dataSource.fetchReplyRows(
      parentId: parentId,
      page: page,
    );
    if (rows.isEmpty) return [];
    final likedIds = await _dataSource.fetchLikedCommentIds(
      rows.map((r) => r['id'] as String).toList(),
    );
    return rows.map((r) => _toEntity(r, likedIds)).toList();
  }

  @override
  Future<Comment> addComment({
    required String videoId,
    required String content,
    String? parentId,
  }) async {
    final row = await _dataSource.addComment(
      videoId: videoId,
      content: content,
      parentId: parentId,
    );
    return _toEntity(row, {});
  }

  @override
  Future<void> deleteComment(String commentId) =>
      _dataSource.deleteComment(commentId);

  @override
  Future<void> likeComment(String commentId) =>
      _dataSource.likeComment(commentId);

  @override
  Future<void> unlikeComment(String commentId) =>
      _dataSource.unlikeComment(commentId);
}
