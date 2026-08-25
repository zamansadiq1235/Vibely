import '../../../auth/domain/entities/app_profile.dart';
import '../../../feed/domain/entities/video_post.dart';
import '../entities/hashtag_result.dart';

abstract class SearchRepository {
  /// Matches username or full name, most-followed first.
  Future<List<AppProfile>> searchUsers({
    required String query,
    required int page,
  });

  /// Matches caption text, newest first. RLS still applies — private/
  /// friends-only videos never surface to a viewer who can't see them.
  Future<List<VideoPost>> searchVideos({
    required String query,
    required int page,
  });

  /// Matches the hashtag itself (without the leading #), most-used first.
  Future<List<HashtagResult>> searchHashtags({
    required String query,
    required int page,
  });
}
