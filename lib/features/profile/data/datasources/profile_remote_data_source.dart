// ignore_for_file: use_null_aware_elements

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_exception.dart';

class ProfileRemoteDataSource {
  ProfileRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>> fetchProfileRow(String userId) async {
    try {
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      return row;
    } on PostgrestException {
      throw AppException.unknown('This profile could not be found.');
    } catch (_) {
      throw AppException.network();
    }
  }

  Future<void> updateProfile({
    required String userId,
    required String fullName,
    required String userName,
    required String bio,
    String? avatarPath,
  }) async {
    try {
      await _client
          .from('profiles')
          .update({
            'full_name': fullName,
            'username': userName,
            'bio': bio,
            if (avatarPath != null) 'avatar_path': avatarPath,
          })
          .eq('id', userId);

      // Best-effort sync of user metadata in Supabase Auth
      try {
        await _client.auth.updateUser(
          UserAttributes(data: {'username': userName, 'full_name': fullName}),
        );
      } catch (_) {}
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw AppException.unknown(
          'Username "$userName" is already taken. Please choose another.',
        );
      }
      throw AppException.unknown(
        e.message.isNotEmpty ? e.message : 'Could not update your profile.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.network();
    }
  }

  Future<bool> isFollowing({
    required String followerId,
    required String followingId,
  }) async {
    try {
      final row = await _client
          .from('follows')
          .select('id')
          .eq('follower_id', followerId)
          .eq('following_id', followingId)
          .maybeSingle();
      return row != null;
    } on PostgrestException catch (e) {
      throw AppException.unknown(
        e.message.isNotEmpty ? e.message : 'Could not load follow status.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.network();
    }
  }

  Future<void> follow({
    required String followerId,
    required String followingId,
  }) async {
    try {
      await _client.from('follows').insert({
        'follower_id': followerId,
        'following_id': followingId,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') return; // already following
      throw AppException.unknown(
        e.message.isNotEmpty ? e.message : 'Could not follow this user.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.network();
    }
  }

  Future<void> unfollow({
    required String followerId,
    required String followingId,
  }) async {
    try {
      await _client
          .from('follows')
          .delete()
          .eq('follower_id', followerId)
          .eq('following_id', followingId);
    } on PostgrestException catch (e) {
      throw AppException.unknown(
        e.message.isNotEmpty ? e.message : 'Could not unfollow this user.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.network();
    }
  }

  /// Returns the active (pending/accepted) friend_requests row between
  /// the two users, in either direction, or null if there is none.
  Future<Map<String, dynamic>?> fetchActiveFriendRequest({
    required String userA,
    required String userB,
  }) async {
    try {
      return await _client
          .from('friend_requests')
          .select()
          .or(
            'and(sender_id.eq.$userA,receiver_id.eq.$userB),'
            'and(sender_id.eq.$userB,receiver_id.eq.$userA)',
          )
          .inFilter('status', ['pending', 'accepted'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
    } on PostgrestException catch (e) {
      throw AppException.unknown(
        e.message.isNotEmpty ? e.message : 'Could not load friend status.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.network();
    }
  }

  Future<void> sendFriendRequest({
    required String senderId,
    required String receiverId,
  }) async {
    try {
      await _client.from('friend_requests').insert({
        'sender_id': senderId,
        'receiver_id': receiverId,
        'status': 'pending',
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw AppException.unknown('Friend request already sent.');
      }
      throw AppException.unknown(
        e.message.isNotEmpty ? e.message : 'Could not send friend request.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.network();
    }
  }

  Future<void> updateFriendRequestStatus({
    required String requestId,
    required String status,
  }) async {
    try {
      await _client
          .from('friend_requests')
          .update({'status': status})
          .eq('id', requestId);
    } on PostgrestException catch (e) {
      throw AppException.unknown(
        e.message.isNotEmpty ? e.message : 'Could not update friend request.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.network();
    }
  }

  Future<void> deleteFriendRequest(String requestId) async {
    try {
      await _client.from('friend_requests').delete().eq('id', requestId);
    } on PostgrestException catch (e) {
      throw AppException.unknown(
        e.message.isNotEmpty ? e.message : 'Could not remove this connection.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.network();
    }
  }
}
