import '../../../feed/domain/entities/video_post.dart';

abstract class SavedVideosRepository {
  Future<void> saveVideo(String videoId);
  Future<void> unsaveVideo(String videoId);

  /// The current user's saved videos, newest-saved first, paged. Backs
  /// the dedicated Saved Videos screen (spec §15).
  Future<List<VideoPost>> fetchSavedVideos({required int page});
}
