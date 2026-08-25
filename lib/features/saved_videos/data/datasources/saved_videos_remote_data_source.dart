import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';

class SavedVideosRemoteDataSource {
  SavedVideosRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const _uniqueViolation = '23505';

  Future<void> saveVideo(String videoId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw AppException.unauthorized();
    try {
      await _client.from('saved_videos').insert({
        'video_id': videoId,
        'user_id': userId,
      });
    } on PostgrestException catch (e) {
      if (e.code == _uniqueViolation) return;
      throw AppException.unknown(
        e.message.isNotEmpty ? e.message : 'Could not save this video.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.network();
    }
  }

  Future<void> unsaveVideo(String videoId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw AppException.unauthorized();
    try {
      await _client
          .from('saved_videos')
          .delete()
          .eq('video_id', videoId)
          .eq('user_id', userId);
    } on PostgrestException catch (e) {
      throw AppException.unknown(
        e.message.isNotEmpty ? e.message : 'Could not unsave this video.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.network();
    }
  }

  /// `saved_videos` is the *ownership* table for the pagination
  /// contract, joined out to the full video + author so the Saved
  /// Videos screen doesn't need a second round trip per item.
  Future<List<Map<String, dynamic>>> fetchSavedVideoRows({
    required int page,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw AppException.unauthorized();
    final from = page * AppConstants.feedPageSize;
    final to = from + AppConstants.feedPageSize - 1;
    try {
      final rows = await _client
          .from('saved_videos')
          .select(
            'video_id, videos(*, profiles!videos_user_id_fkey(username, avatar_path))',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(from, to);
      return List<Map<String, dynamic>>.from(rows as List);
    } on PostgrestException catch (e) {
      throw AppException.unknown(
        e.message.isNotEmpty ? e.message : 'Could not load your saved videos.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.network();
    }
  }
}
