import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/supabase_client_provider.dart';
import '../../../feed/domain/entities/video_post.dart';
import '../../../feed/presentation/providers/feed_provider.dart';
import '../../data/datasources/repost_remote_data_source.dart';
import '../../data/repositories/repost_repository_impl.dart';
import '../../domain/repositories/repost_repository.dart';

// ---------- Dependency injection ----------

final repostRemoteDataSourceProvider = Provider<RepostRemoteDataSource>((ref) {
  return RepostRemoteDataSource(ref.watch(supabaseClientProvider));
});

final repostRepositoryProvider = Provider<RepostRepository>((ref) {
  return RepostRepositoryImpl(
    ref.watch(repostRemoteDataSourceProvider),
    ref.watch(feedRemoteDataSourceProvider),
  );
});

// ---------- Reposted videos list (keyed by userId — viewable on any profile) ----------

class RepostedVideosState {
  const RepostedVideosState({required this.videos, required this.hasMore});
  final List<VideoPost> videos;
  final bool hasMore;

  RepostedVideosState copyWith({List<VideoPost>? videos, bool? hasMore}) {
    return RepostedVideosState(
      videos: videos ?? this.videos,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class RepostedVideosNotifier extends AsyncNotifier<RepostedVideosState> {
  RepostedVideosNotifier(this._userId);

  final String _userId;
  int _page = 0;
  bool _isFetchingMore = false;

  @override
  Future<RepostedVideosState> build() async {
    _page = 0;
    final videos = await ref
        .read(repostRepositoryProvider)
        .fetchRepostedVideos(userId: _userId, page: 0);
    return RepostedVideosState(
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
          .read(repostRepositoryProvider)
          .fetchRepostedVideos(userId: userId, page: nextPage);
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

  void removeLocal(String videoId) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        videos: current.videos.where((v) => v.id != videoId).toList(),
      ),
    );
  }
}

final repostedVideosProvider =
    AsyncNotifierProvider.family<
      RepostedVideosNotifier,
      RepostedVideosState,
      String
    >(RepostedVideosNotifier.new);

// ---------- Repost/un-repost action ----------

class RepostActions {
  RepostActions(this._ref);
  final Ref _ref;

  Future<void> setReposted(
    String videoId,
    bool reposted, {
    required String currentUserId,
  }) async {
    _ref
        .read(feedProvider.notifier)
        .patchVideo(
          videoId,
          (post) => post.copyWith(
            isRepostedByMe: reposted,
            repostsCount: post.repostsCount + (reposted ? 1 : -1),
          ),
        );
    if (!reposted) {
      _ref
          .read(repostedVideosProvider(currentUserId).notifier)
          .removeLocal(videoId);
    }

    try {
      final repo = _ref.read(repostRepositoryProvider);
      if (reposted) {
        await repo.repostVideo(videoId);
      } else {
        await repo.removeRepost(videoId);
      }
      _ref.invalidate(repostedVideosProvider(currentUserId));
    } catch (e) {
      _ref
          .read(feedProvider.notifier)
          .patchVideo(
            videoId,
            (post) => post.copyWith(
              isRepostedByMe: !reposted,
              repostsCount: post.repostsCount + (reposted ? -1 : 1),
            ),
          );
      rethrow;
    }
  }
}

final repostActionsProvider = Provider((ref) => RepostActions(ref));
