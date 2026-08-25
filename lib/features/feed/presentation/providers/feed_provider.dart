import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/supabase_client_provider.dart';
import '../../data/datasources/feed_remote_data_source.dart';
import '../../data/repositories/feed_repository_impl.dart';
import '../../domain/entities/video_post.dart';
import '../../domain/repositories/feed_repository.dart';

// ---------- Dependency injection ----------

final feedRemoteDataSourceProvider = Provider<FeedRemoteDataSource>((ref) {
  return FeedRemoteDataSource(ref.watch(supabaseClientProvider));
});

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepositoryImpl(ref.watch(feedRemoteDataSourceProvider));
});

// ---------- Feed state ----------

class FeedState {
  const FeedState({required this.videos, required this.hasMore});

  final List<VideoPost> videos;
  final bool hasMore;

  FeedState copyWith({List<VideoPost>? videos, bool? hasMore}) {
    return FeedState(
      videos: videos ?? this.videos,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class FeedNotifier extends AsyncNotifier<FeedState> {
  int _page = 0;
  bool _isFetchingMore = false;

  @override
  Future<FeedState> build() async {
    _page = 0;
    final videos = await ref.read(feedRepositoryProvider).fetchFeed(page: 0);
    return FeedState(
      videos: videos,
      hasMore: videos.length == AppConstants.feedPageSize,
    );
  }

  /// Called when the PageView nears the end of the loaded list (spec §29:
  /// "20 videos -> Next 20" pagination, never fetching unlimited data).
  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore || _isFetchingMore) return;

    _isFetchingMore = true;
    final nextPage = _page + 1;
    try {
      final more = await ref
          .read(feedRepositoryProvider)
          .fetchFeed(page: nextPage);
      _page = nextPage;
      state = AsyncData(
        current.copyWith(
          videos: [...current.videos, ...more],
          hasMore: more.length == AppConstants.feedPageSize,
        ),
      );
    } catch (_) {
      // Leave state as-is on failure; the feed screen can retry by
      // scrolling again, which re-triggers loadMore().
    } finally {
      _isFetchingMore = false;
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Applies a local update to a single video — used by LikeActions
  /// (Phase 7) for the optimistic like/unlike UI update, and available
  /// to any future feature that needs to patch a feed item's displayed
  /// counts without a full refetch.
  void patchVideo(String videoId, VideoPost Function(VideoPost) updater) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        videos: [
          for (final v in current.videos) v.id == videoId ? updater(v) : v,
        ],
      ),
    );
  }
}

final feedProvider = AsyncNotifierProvider<FeedNotifier, FeedState>(
  FeedNotifier.new,
);

// ---------- A single user's own uploads (Profile "Videos" tab) ----------

class UserVideosNotifier extends AsyncNotifier<FeedState> {
  UserVideosNotifier(this._userId);

  final String _userId;
  int _page = 0;
  bool _isFetchingMore = false;

  @override
  Future<FeedState> build() async {
    _page = 0;
    final videos = await ref
        .read(feedRepositoryProvider)
        .fetchUserVideos(userId: _userId, page: 0);
    return FeedState(
      videos: videos,
      hasMore: videos.length == AppConstants.feedPageSize,
    );
  }

  Future<void> loadMore(String userId) async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore || _isFetchingMore) return;
    _isFetchingMore = true;
    final nextPage = _page + 1;
    try {
      final more = await ref
          .read(feedRepositoryProvider)
          .fetchUserVideos(userId: userId, page: nextPage);
      _page = nextPage;
      state = AsyncData(
        current.copyWith(
          videos: [...current.videos, ...more],
          hasMore: more.length == AppConstants.feedPageSize,
        ),
      );
    } catch (_) {
    } finally {
      _isFetchingMore = false;
    }
  }
}

final userVideosProvider =
    AsyncNotifierProvider.family<UserVideosNotifier, FeedState, String>(
      UserVideosNotifier.new,
    );
