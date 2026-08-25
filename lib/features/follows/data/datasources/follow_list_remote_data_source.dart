import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';

class FollowListRemoteDataSource {
  FollowListRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> fetchFollowerRows({
    required String userId,
    required int page,
  }) async {
    final from = page * AppConstants.followListPageSize;
    final to = from + AppConstants.followListPageSize - 1;
    try {
      final rows = await _client
          .from('follows')
          .select('follower:profiles!follows_follower_id_fkey(*)')
          .eq('following_id', userId)
          .order('created_at', ascending: false)
          .range(from, to);
      return List<Map<String, dynamic>>.from(rows as List);
    } on PostgrestException catch (e) {
      throw AppException.unknown(
        e.message.isNotEmpty ? e.message : 'Could not load followers.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.network();
    }
  }

  Future<List<Map<String, dynamic>>> fetchFollowingRows({
    required String userId,
    required int page,
  }) async {
    final from = page * AppConstants.followListPageSize;
    final to = from + AppConstants.followListPageSize - 1;
    try {
      final rows = await _client
          .from('follows')
          .select('following:profiles!follows_following_id_fkey(*)')
          .eq('follower_id', userId)
          .order('created_at', ascending: false)
          .range(from, to);
      return List<Map<String, dynamic>>.from(rows as List);
    } on PostgrestException catch (e) {
      throw AppException.unknown(
        e.message.isNotEmpty ? e.message : 'Could not load following.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.network();
    }
  }

  /// Which of [profileIds] the *viewer* (current user) already follows —
  /// batched into one query so each list row doesn't need its own
  /// round trip to decide its Follow/Following button state.
  Future<Set<String>> fetchViewerFollowingIds(List<String> profileIds) async {
    final viewerId = _client.auth.currentUser?.id;
    if (viewerId == null || profileIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('follows')
          .select('following_id')
          .eq('follower_id', viewerId)
          .inFilter('following_id', profileIds);
      return (rows as List).map((r) => r['following_id'] as String).toSet();
    } catch (_) {
      return {};
    }
  }
}
