import '../entities/video_post.dart';

abstract class FeedRepository {
  /// Zero-indexed `page` of `AppConstants.feedPageSize` videos, newest
  /// first (spec §28: the simple initial ranking is recency, with the
  /// query structured so a smarter ranking can replace the `order by`
  /// later without changing this interface).
  Future<List<VideoPost>> fetchFeed({required int page});

  /// A single user's own uploads — backs the Profile "Videos" tab.
  Future<List<VideoPost>> fetchUserVideos({
    required String userId,
    required int page,
  });

  /// Records a view once the app's own "watched for the minimum
  /// duration" rule (spec §37) is satisfied.
  Future<void> recordView(String videoId);
}
