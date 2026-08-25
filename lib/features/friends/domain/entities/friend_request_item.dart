import '../../../auth/domain/entities/app_profile.dart';

class FriendRequestItem {
  const FriendRequestItem({
    required this.requestId,
    required this.profile,
    required this.createdAt,
  });

  final String requestId;

  /// The *other* person in the request — the sender if this is a
  /// received request, the receiver if this is a sent one.
  final AppProfile profile;
  final DateTime createdAt;
}
