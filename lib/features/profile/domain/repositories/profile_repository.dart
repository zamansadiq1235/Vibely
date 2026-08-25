import '../../../auth/domain/entities/app_profile.dart';
import '../entities/relationship_info.dart';

abstract class ProfileRepository {
  Future<AppProfile> fetchProfile(String userId);

  Future<void> updateProfile({
    required String fullName,
    required String userName,
    required String bio,
    String? avatarPath,
  });

  /// Relationship of [currentUserId] towards [targetUserId].
  Future<RelationshipInfo> fetchRelationship({
    required String currentUserId,
    required String targetUserId,
  });

  Future<void> follow(String targetUserId);
  Future<void> unfollow(String targetUserId);

  Future<void> sendFriendRequest(String targetUserId);
  Future<void> cancelFriendRequest(String requestId);
  Future<void> acceptFriendRequest(String requestId);
  Future<void> rejectFriendRequest(String requestId);
  Future<void> removeFriend(String requestId);
}
