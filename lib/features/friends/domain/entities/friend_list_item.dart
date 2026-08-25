import '../../../auth/domain/entities/app_profile.dart';

class FriendListItem {
  const FriendListItem({required this.profile, required this.friendRequestId});

  final AppProfile profile;

  /// Needed to call removeFriend (which deletes this friend_requests row).
  final String friendRequestId;
}
