import '../../../auth/domain/entities/app_profile.dart';
import '../../../feed/data/datasources/feed_remote_data_source.dart';
import '../../../feed/domain/entities/video_post.dart';
import '../../domain/entities/hashtag_result.dart';
import '../../domain/repositories/search_repository.dart';
import '../datasources/search_remote_data_source.dart';

class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl(this._dataSource, this._feedDataSource);

  final SearchRemoteDataSource _dataSource;
  final FeedRemoteDataSource _feedDataSource;

  @override
  Future<List<AppProfile>> searchUsers({required String query, required int page}) async {
    final rows = await _dataSource.searchUserRows(query: query, page: page);
    return rows.map(AppProfile.fromMap).toList();
  }

  @override
  Future<List<VideoPost>> searchVideos({required String query, required int page}) async {
    final rows = await _dataSource.searchVideoRows(query: query, page: page);
    if (rows.isEmpty) return [];

    final ids = rows.map((r) => r['id'] as String).toList();
    final flags = await _feedDataSource.fetchInteractionFlags(ids);

    return rows.map((row) {
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
        isSavedByMe: flags.saved.contains(row['id']),
        isRepostedByMe: flags.reposted.contains(row['id']),
        createdAt: DateTime.parse(row['created_at'] as String),
      );
    }).toList();
  }

  @override
  Future<List<HashtagResult>> searchHashtags({required String query, required int page}) async {
    final rows = await _dataSource.searchHashtagRows(query: query, page: page);
    return rows
        .map((r) => HashtagResult(
              id: r['id'] as String,
              tag: r['tag'] as String,
              usageCount: (r['usage_count'] as int?) ?? 0,
            ))
        .toList();
  }
}