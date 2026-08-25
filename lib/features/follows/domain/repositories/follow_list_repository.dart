import '../entities/follow_list_item.dart';

abstract class FollowListRepository {
  /// Everyone following [userId], newest-followed first.
  Future<List<FollowListItem>> fetchFollowers({
    required String userId,
    required int page,
  });

  /// Everyone [userId] follows, newest-followed first.
  Future<List<FollowListItem>> fetchFollowing({
    required String userId,
    required int page,
  });
}
