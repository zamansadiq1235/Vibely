import '../entities/friend_list_item.dart';
import '../entities/friend_request_item.dart';

abstract class FriendsRepository {
  /// [userId]'s accepted friends, newest-accepted first. Viewable on any
  /// profile (spec §21).
  Future<List<FriendListItem>> fetchFriends({
    required String userId,
    required int page,
  });

  /// Pending requests sent *to* the current user.
  Future<List<FriendRequestItem>> fetchReceivedRequests({required int page});

  /// Pending requests the current user has sent, still awaiting a reply.
  Future<List<FriendRequestItem>> fetchSentRequests({required int page});
}
