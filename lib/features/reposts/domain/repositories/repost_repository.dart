import '../../../feed/domain/entities/video_post.dart';

abstract class RepostRepository {
  Future<void> repostVideo(String videoId);
  Future<void> removeRepost(String videoId);

  /// A given user's reposted videos, newest-reposted first, paged.
  /// Backs the Profile "Reposts" tab and the dedicated Reposted Videos
  /// screen (spec §16).
  Future<List<VideoPost>> fetchRepostedVideos({
    required String userId,
    required int page,
  });
}
