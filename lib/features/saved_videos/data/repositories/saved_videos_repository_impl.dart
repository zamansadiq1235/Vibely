import '../../../feed/data/datasources/feed_remote_data_source.dart';
import '../../../feed/domain/entities/video_post.dart';
import '../../domain/repositories/saved_videos_repository.dart';
import '../datasources/saved_videos_remote_data_source.dart';

class SavedVideosRepositoryImpl implements SavedVideosRepository {
  SavedVideosRepositoryImpl(this._dataSource, this._feedDataSource);

  final SavedVideosRemoteDataSource _dataSource;

  /// Reused only for its URL-resolution + liked/reposted-id helpers, so
  /// this feature doesn't duplicate that logic — same pattern as
  /// FeedRepositoryImpl itself.
  final FeedRemoteDataSource _feedDataSource;

  @override
  Future<void> saveVideo(String videoId) => _dataSource.saveVideo(videoId);

  @override
  Future<void> unsaveVideo(String videoId) => _dataSource.unsaveVideo(videoId);

  @override
  Future<List<VideoPost>> fetchSavedVideos({required int page}) async {
    final rows = await _dataSource.fetchSavedVideoRows(page: page);
    if (rows.isEmpty) return [];

    final videoRows = rows
        .map((r) => r['videos'] as Map<String, dynamic>?)
        .where((v) => v != null)
        .cast<Map<String, dynamic>>()
        .toList();
    if (videoRows.isEmpty) return [];

    final ids = videoRows.map((r) => r['id'] as String).toList();
    final flags = await _feedDataSource.fetchInteractionFlags(ids);

    return videoRows.map((row) {
      final author = row['profiles'] as Map<String, dynamic>?;
      return VideoPost(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        username: author?['username'] as String? ?? 'unknown',
        avatarUrl: _feedDataSource.resolveAvatarUrl(author?['avatar_path'] as String?),
        videoUrl: _feedDataSource.resolveVideoUrl(row['video_path'] as String),
        thumbnailUrl: _feedDataSource.resolveThumbnailUrl(row['thumbnail_path'] as String?),
        caption: row['caption'] as String? ?? '',
        viewsCount: (row['views_count'] as int?) ?? 0,
        likesCount: (row['likes_count'] as int?) ?? 0,
        commentsCount: (row['comments_count'] as int?) ?? 0,
        sharesCount: (row['shares_count'] as int?) ?? 0,
        savesCount: (row['saves_count'] as int?) ?? 0,
        repostsCount: (row['reposts_count'] as int?) ?? 0,
        isLikedByMe: flags.liked.contains(row['id']),
        isSavedByMe: true, // this list is, by definition, all saved videos
        isRepostedByMe: flags.reposted.contains(row['id']),
        createdAt: DateTime.parse(row['created_at'] as String),
      );
    }).toList();
  }
}
