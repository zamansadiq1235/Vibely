import '../../domain/entities/video_post.dart';
import '../../domain/repositories/feed_repository.dart';
import '../datasources/feed_remote_data_source.dart';

class FeedRepositoryImpl implements FeedRepository {
  FeedRepositoryImpl(this._dataSource);

  final FeedRemoteDataSource _dataSource;

  Future<List<VideoPost>> _toPosts(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return [];
    final ids = rows.map((r) => r['id'] as String).toList();

    // Phase 13: one RPC round trip instead of three separate queries —
    // see migration 0007 and fetchInteractionFlags' doc comment.
    final flags = await _dataSource.fetchInteractionFlags(ids);

    return rows.map((row) {
      final author = row['profiles'] as Map<String, dynamic>?;
      return VideoPost(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        username: author?['username'] as String? ?? 'unknown',
        avatarUrl: _dataSource.resolveAvatarUrl(author?['avatar_path'] as String?),
        videoUrl: _dataSource.resolveVideoUrl(row['video_path'] as String),
        thumbnailUrl: _dataSource.resolveThumbnailUrl(row['thumbnail_path'] as String?),
        caption: row['caption'] as String? ?? '',
        viewsCount: (row['views_count'] as int?) ?? 0,
        likesCount: (row['likes_count'] as int?) ?? 0,
        commentsCount: (row['comments_count'] as int?) ?? 0,
        sharesCount: (row['shares_count'] as int?) ?? 0,
        savesCount: (row['saves_count'] as int?) ?? 0,
        repostsCount: (row['reposts_count'] as int?) ?? 0,
        isLikedByMe: flags.liked.contains(row['id']),
        isSavedByMe: flags.saved.contains(row['id']),
        isRepostedByMe: flags.reposted.contains(row['id']),
        createdAt: DateTime.parse(row['created_at'] as String),
      );
    }).toList();
  }

  @override
  Future<List<VideoPost>> fetchFeed({required int page}) async {
    final rows = await _dataSource.fetchFeedRows(page: page);
    return _toPosts(rows);
  }

  @override
  Future<List<VideoPost>> fetchUserVideos({required String userId, required int page}) async {
    final rows = await _dataSource.fetchUserVideoRows(userId: userId, page: page);
    return _toPosts(rows);
  }

  @override
  Future<void> recordView(String videoId) => _dataSource.recordView(videoId);
}
