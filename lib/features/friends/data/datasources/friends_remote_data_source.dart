import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';

class FriendsRemoteDataSource {
  FriendsRemoteDataSource(this._client);

  final SupabaseClient _client;

  /// One query, both directions: friend_requests where [userId] is
  /// either sender or receiver and status = accepted. Both possible
  /// "other person" profiles are joined so the repository can pick
  /// whichever one isn't [userId] per row, without a second round trip.
  Future<List<Map<String, dynamic>>> fetchFriendRows({
    required String userId,
    required int page,
  }) async {
    final from = page * AppConstants.followListPageSize;
    final to = from + AppConstants.followListPageSize - 1;
    try {
      final rows = await _client
          .from('friend_requests')
          .select('''
            id, sender_id, receiver_id, created_at,
            sender:profiles!friend_requests_sender_id_fkey(*),
            receiver:profiles!friend_requests_receiver_id_fkey(*)
          ''')
          .eq('status', 'accepted')
          .or('sender_id.eq.$userId,receiver_id.eq.$userId')
          .order('created_at', ascending: false)
          .range(from, to);
      return List<Map<String, dynamic>>.from(rows as List);
    } on PostgrestException catch (e) {
      throw AppException.unknown(
        e.message.isNotEmpty ? e.message : 'Could not load friends.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.network();
    }
  }

  Future<List<Map<String, dynamic>>> fetchReceivedRequestRows({
    required int page,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw AppException.unauthorized();
    final from = page * AppConstants.followListPageSize;
    final to = from + AppConstants.followListPageSize - 1;
    try {
      final rows = await _client
          .from('friend_requests')
          .select(
            'id, created_at, sender:profiles!friend_requests_sender_id_fkey(*)',
          )
          .eq('receiver_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .range(from, to);
      return List<Map<String, dynamic>>.from(rows as List);
    } on PostgrestException catch (e) {
      throw AppException.unknown(
        e.message.isNotEmpty ? e.message : 'Could not load friend requests.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.network();
    }
  }

  Future<List<Map<String, dynamic>>> fetchSentRequestRows({
    required int page,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw AppException.unauthorized();
    final from = page * AppConstants.followListPageSize;
    final to = from + AppConstants.followListPageSize - 1;
    try {
      final rows = await _client
          .from('friend_requests')
          .select(
            'id, created_at, receiver:profiles!friend_requests_receiver_id_fkey(*)',
          )
          .eq('sender_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .range(from, to);
      return List<Map<String, dynamic>>.from(rows as List);
    } on PostgrestException catch (e) {
      throw AppException.unknown(
        e.message.isNotEmpty ? e.message : 'Could not load sent requests.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.network();
    }
  }
}
