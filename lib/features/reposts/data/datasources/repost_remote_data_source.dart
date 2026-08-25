import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';

class RepostRemoteDataSource {
  RepostRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const _uniqueViolation = '23505';

  Future<void> repostVideo(String videoId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw AppException.unauthorized();
    try {
      await _client.from('reposts').insert({
        'video_id': videoId,
        'user_id': userId,
      });
    } on PostgrestException catch (e) {
      if (e.code == _uniqueViolation) return; // already reposted — fine
      throw AppException.unknown(
        e.message.isNotEmpty ? e.message : 'Could not repost this video.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.network();
    }
  }

  Future<void> removeRepost(String videoId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw AppException.unauthorized();
    try {
      await _client
          .from('reposts')
          .delete()
          .eq('video_id', videoId)
          .eq('user_id', userId);
    } on PostgrestException catch (e) {
      throw AppException.unknown(
        e.message.isNotEmpty ? e.message : 'Could not remove this repost.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.network();
    }
  }

  Future<List<Map<String, dynamic>>> fetchRepostedVideoRows({
    required String userId,
    required int page,
  }) async {
    final from = page * AppConstants.feedPageSize;
    final to = from + AppConstants.feedPageSize - 1;
    try {
      // RLS lets anyone view reposts
      final rows = await _client
          .from('reposts')
          .select(
            'video_id, videos(*, profiles!videos_user_id_fkey(username, avatar_path))',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(from, to);
      return List<Map<String, dynamic>>.from(rows as List);
    } on PostgrestException catch (e) {
      throw AppException.unknown(
        e.message.isNotEmpty ? e.message : 'Could not load reposts.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.network();
    }
  }
}
