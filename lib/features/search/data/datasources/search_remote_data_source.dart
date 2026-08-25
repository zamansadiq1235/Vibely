import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';

class SearchRemoteDataSource {
  SearchRemoteDataSource(this._client);

  final SupabaseClient _client;

  /// Escapes characters that are special to PostgREST's ilike pattern
  /// syntax so a search containing them (e.g. "50%") doesn't behave
  /// like a wildcard the user didn't type.
  String _sanitize(String query) {
    return query.trim().replaceAll('%', r'\%').replaceAll('_', r'\_');
  }

  Future<List<Map<String, dynamic>>> searchUserRows({
    required String query,
    required int page,
  }) async {
    final q = _sanitize(query);
    if (q.isEmpty) return [];
    final from = page * AppConstants.searchPageSize;
    final to = from + AppConstants.searchPageSize - 1;
    try {
      // Backed by the gin_trgm_ops indexes on username/full_name
      // (migration 0001), so this stays fast even as the table grows.
      final rows = await _client
          .from('profiles')
          .select()
          .or('username.ilike.%$q%,full_name.ilike.%$q%')
          .order('followers_count', ascending: false)
          .range(from, to);
      return List<Map<String, dynamic>>.from(rows as List);
    } on PostgrestException catch (e) {
      throw AppException.unknown(
        e.message.isNotEmpty ? e.message : 'Search failed.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.network();
    }
  }

  Future<List<Map<String, dynamic>>> searchVideoRows({
    required String query,
    required int page,
  }) async {
    final q = _sanitize(query);
    if (q.isEmpty) return [];
    final from = page * AppConstants.searchPageSize;
    final to = from + AppConstants.searchPageSize - 1;
    try {
      final rows = await _client
          .from('videos')
          .select('*, profiles!videos_user_id_fkey(username, avatar_path)')
          .eq('is_deleted', false)
          .ilike('caption', '%$q%')
          .order('created_at', ascending: false)
          .range(from, to);
      return List<Map<String, dynamic>>.from(rows as List);
    } on PostgrestException catch (e) {
      throw AppException.unknown(
        e.message.isNotEmpty ? e.message : 'Search failed.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.network();
    }
  }

  Future<List<Map<String, dynamic>>> searchHashtagRows({
    required String query,
    required int page,
  }) async {
    // Hashtags are stored and searched without the leading '#'.
    final q = _sanitize(query).replaceFirst(RegExp(r'^#'), '');
    if (q.isEmpty) return [];
    final from = page * AppConstants.searchPageSize;
    final to = from + AppConstants.searchPageSize - 1;
    try {
      final rows = await _client
          .from('hashtags')
          .select()
          .ilike('tag', '%$q%')
          .order('usage_count', ascending: false)
          .range(from, to);
      return List<Map<String, dynamic>>.from(rows as List);
    } on PostgrestException catch (e) {
      throw AppException.unknown(
        e.message.isNotEmpty ? e.message : 'Search failed.',
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
