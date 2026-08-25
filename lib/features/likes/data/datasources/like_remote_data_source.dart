import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_exception.dart';

class LikeRemoteDataSource {
  LikeRemoteDataSource(this._client);

  final SupabaseClient _client;

  // Postgres unique_violation — see the UNIQUE(video_id, user_id)
  // constraint on video_likes (migration 0001).
  static const _uniqueViolation = '23505';

  Future<void> likeVideo(String videoId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw AppException.unauthorized();
    try {
      await _client.from('video_likes').insert({
        'video_id': videoId,
        'user_id': userId,
      });
    } on PostgrestException catch (e) {
      if (e.code == _uniqueViolation) return; // already liked — fine
      throw AppException.unknown(
        e.message.isNotEmpty ? e.message : 'Could not like this video.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.network();
    }
  }

  Future<void> unlikeVideo(String videoId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw AppException.unauthorized();
    try {
      await _client
          .from('video_likes')
          .delete()
          .eq('video_id', videoId)
          .eq('user_id', userId);
    } on PostgrestException catch (e) {
      throw AppException.unknown(
        e.message.isNotEmpty ? e.message : 'Could not unlike this video.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.network();
    }
  }
}
