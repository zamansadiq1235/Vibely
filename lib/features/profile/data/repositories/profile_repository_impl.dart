import '../../../../core/errors/app_exception.dart';
import '../../../auth/domain/entities/app_profile.dart';
import '../../domain/entities/relationship_info.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_data_source.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._dataSource, this._currentUserId);

  final ProfileRemoteDataSource _dataSource;

  /// Supplied by the caller (Riverpod provider) since this repository
  /// has no notion of "current user" on its own.
  final String? Function() _currentUserId;

  @override
  Future<AppProfile> fetchProfile(String userId) async {
    final row = await _dataSource.fetchProfileRow(userId);
    return AppProfile.fromMap(row);
  }

  @override
  Future<void> updateProfile({
    required String fullName,
    required String userName,
    required String bio,
    String? avatarPath,
  }) async {
    final uid = _currentUserId();
    if (uid == null) throw AppException.unauthorized();
    await _dataSource.updateProfile(
      userName: userName,
      userId: uid,
      fullName: fullName,
      bio: bio,
      avatarPath: avatarPath,
      
    );
  }

  @override
  Future<RelationshipInfo> fetchRelationship({
    required String currentUserId,
    required String targetUserId,
  }) async {
    if (currentUserId == targetUserId) return RelationshipInfo.none;

    final following = await _dataSource.isFollowing(
      followerId: currentUserId,
      followingId: targetUserId,
    );

    final requestRow = await _dataSource.fetchActiveFriendRequest(
      userA: currentUserId,
      userB: targetUserId,
    );

    FriendStatus friendStatus = FriendStatus.none;
    String? requestId;
    if (requestRow != null) {
      requestId = requestRow['id'] as String;
      final status = requestRow['status'] as String;
      final senderId = requestRow['sender_id'] as String;
      if (status == 'accepted') {
        friendStatus = FriendStatus.friends;
      } else if (status == 'pending') {
        friendStatus = senderId == currentUserId
            ? FriendStatus.requestSentByMe
            : FriendStatus.requestReceivedByMe;
      }
    }

    return RelationshipInfo(
      isFollowing: following,
      friendStatus: friendStatus,
      friendRequestId: requestId,
    );
  }

  @override
  Future<void> follow(String targetUserId) async {
    final uid = _currentUserId();
    if (uid == null) throw AppException.unauthorized();
    await _dataSource.follow(followerId: uid, followingId: targetUserId);
  }

  @override
  Future<void> unfollow(String targetUserId) async {
    final uid = _currentUserId();
    if (uid == null) throw AppException.unauthorized();
    await _dataSource.unfollow(followerId: uid, followingId: targetUserId);
  }

  @override
  Future<void> sendFriendRequest(String targetUserId) async {
    final uid = _currentUserId();
    if (uid == null) throw AppException.unauthorized();
    await _dataSource.sendFriendRequest(
      senderId: uid,
      receiverId: targetUserId,
    );
  }

  @override
  Future<void> cancelFriendRequest(String requestId) {
    return _dataSource.updateFriendRequestStatus(
      requestId: requestId,
      status: 'cancelled',
    );
  }

  @override
  Future<void> acceptFriendRequest(String requestId) {
    return _dataSource.updateFriendRequestStatus(
      requestId: requestId,
      status: 'accepted',
    );
  }

  @override
  Future<void> rejectFriendRequest(String requestId) {
    return _dataSource.updateFriendRequestStatus(
      requestId: requestId,
      status: 'rejected',
    );
  }

  @override
  Future<void> removeFriend(String requestId) {
    return _dataSource.deleteFriendRequest(requestId);
  }
}
