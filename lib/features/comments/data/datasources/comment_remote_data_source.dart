import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';

class CommentRemoteDataSource {
  CommentRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const _uniqueViolation = '23505';

  Future<List<Map<String, dynamic>>> fetchCommentRows({
    required String videoId,
    required int page,
  }) async {
    final from = page * AppConstants.commentsPageSize;
    final to = from + AppConstants.commentsPageSize - 1;
    try {
      final rows = await _client
          .from('comments')
          .select('*, profiles!comments_user_id_fkey(username, avatar_path)')
          .eq('video_id', videoId)
          .filter('parent_id', 'is', null)
          .eq('is_deleted', false)
          .order('created_at', ascending: false)
          .range(from, to);
      return List<Map<String, dynamic>>.from(rows as List);
    } on PostgrestException catch (e) {
      throw AppException.unknown(
        e.message.isNotEmpty ? e.message : 'Could not load comments.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.network();
    }
  }

  Future<List<Map<String, dynamic>>> fetchReplyRows({
    required String parentId,
    required int page,
  }) async {
    final from = page * AppConstants.repliesPageSize;
    final to = from + AppConstants.repliesPageSize - 1;
    try {
      final rows = await _client
          .from('comments')
          .select('*, profiles!comments_user_id_fkey(username, avatar_path)')
          .eq('parent_id', parentId)
          .eq('is_deleted', false)
          .order('created_at', ascending: true)
          .range(from, to);
      return List<Map<String, dynamic>>.from(rows as List);
    } on PostgrestException catch (e) {
      throw AppException.unknown(
        e.message.isNotEmpty ? e.message : 'Could not load replies.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.network();
    }
  }

  Future<Set<String>> fetchLikedCommentIds(List<String> commentIds) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || commentIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('comment_likes')
          .select('comment_id')
          .eq('user_id', userId)
          .inFilter('comment_id', commentIds);
      return (rows as List).map((r) => r['comment_id'] as String).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, dynamic>> addComment({
    required String videoId,
    required String content,
    String? parentId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw AppException.unauthorized();
    try {
      return await _client
          .from('comments')
          .insert({
            'video_id': videoId,
            'user_id': userId,
            'parent_id': parentId,
            'content': content,
          })
          .select('*, profiles!comments_user_id_fkey(username, avatar_path)')
          .single();
    } on PostgrestException catch (e) {
      throw AppException.unknown(
        e.message.isNotEmpty ? e.message : 'Could not post your comment.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.network();
    }
  }

  Future<void> deleteComment(String commentId) async {
    try {
      // RLS enforces that only the author can do this
      await _client.from('comments').delete().eq('id', commentId);
    } on PostgrestException catch (e) {
      throw AppException.unknown(
        e.message.isNotEmpty ? e.message : 'Could not delete this comment.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.network();
    }
  }

  Future<void> likeComment(String commentId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw AppException.unauthorized();
    try {
      await _client.from('comment_likes').insert({
        'comment_id': commentId,
        'user_id': userId,
      });
    } on PostgrestException catch (e) {
      if (e.code == _uniqueViolation) return;
      throw AppException.unknown(
        e.message.isNotEmpty ? e.message : 'Could not like this comment.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.network();
    }
  }

  Future<void> unlikeComment(String commentId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw AppException.unauthorized();
    try {
      await _client
          .from('comment_likes')
          .delete()
          .eq('comment_id', commentId)
          .eq('user_id', userId);
    } on PostgrestException catch (e) {
      throw AppException.unknown(
        e.message.isNotEmpty ? e.message : 'Could not unlike this comment.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.network();
    }
  }

  String? resolveAvatarUrl(String? path) => path == null
      ? null
      : _client.storage.from(AppConstants.avatarsBucket).getPublicUrl(path);
}
