import '../../../auth/domain/entities/app_profile.dart';
import '../../domain/entities/friend_list_item.dart';
import '../../domain/entities/friend_request_item.dart';
import '../../domain/repositories/friends_repository.dart';
import '../datasources/friends_remote_data_source.dart';

class FriendsRepositoryImpl implements FriendsRepository {
  FriendsRepositoryImpl(this._dataSource);

  final FriendsRemoteDataSource _dataSource;

  @override
  Future<List<FriendListItem>> fetchFriends({
    required String userId,
    required int page,
  }) async {
    final rows = await _dataSource.fetchFriendRows(userId: userId, page: page);
    return rows.map((row) {
      final isSender = row['sender_id'] == userId;
      final otherProfile =
          (isSender ? row['receiver'] : row['sender']) as Map<String, dynamic>;
      return FriendListItem(
        profile: AppProfile.fromMap(otherProfile),
        friendRequestId: row['id'] as String,
      );
    }).toList();
  }

  @override
  Future<List<FriendRequestItem>> fetchReceivedRequests({
    required int page,
  }) async {
    final rows = await _dataSource.fetchReceivedRequestRows(page: page);
    return rows.map((row) {
      return FriendRequestItem(
        requestId: row['id'] as String,
        profile: AppProfile.fromMap(row['sender'] as Map<String, dynamic>),
        createdAt: DateTime.parse(row['created_at'] as String),
      );
    }).toList();
  }

  @override
  Future<List<FriendRequestItem>> fetchSentRequests({required int page}) async {
    final rows = await _dataSource.fetchSentRequestRows(page: page);
    return rows.map((row) {
      return FriendRequestItem(
        requestId: row['id'] as String,
        profile: AppProfile.fromMap(row['receiver'] as Map<String, dynamic>),
        createdAt: DateTime.parse(row['created_at'] as String),
      );
    }).toList();
  }
}
