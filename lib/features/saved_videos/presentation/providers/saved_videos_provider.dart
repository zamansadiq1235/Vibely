import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/supabase_client_provider.dart';
import '../../../feed/domain/entities/video_post.dart';
import '../../../feed/presentation/providers/feed_provider.dart';
import '../../data/datasources/saved_videos_remote_data_source.dart';
import '../../data/repositories/saved_videos_repository_impl.dart';
import '../../domain/repositories/saved_videos_repository.dart';

// ---------- Dependency injection ----------

final savedVideosRemoteDataSourceProvider =
    Provider<SavedVideosRemoteDataSource>((ref) {
      return SavedVideosRemoteDataSource(ref.watch(supabaseClientProvider));
    });

final savedVideosRepositoryProvider = Provider<SavedVideosRepository>((ref) {
  return SavedVideosRepositoryImpl(
    ref.watch(savedVideosRemoteDataSourceProvider),
    ref.watch(feedRemoteDataSourceProvider),
  );
});

// ---------- Saved Videos screen list ----------

class SavedVideosState {
  const SavedVideosState({required this.videos, required this.hasMore});
  final List<VideoPost> videos;
  final bool hasMore;

  SavedVideosState copyWith({List<VideoPost>? videos, bool? hasMore}) {
    return SavedVideosState(
      videos: videos ?? this.videos,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class SavedVideosNotifier extends AsyncNotifier<SavedVideosState> {
  int _page = 0;
  bool _isFetchingMore = false;

  @override
  Future<SavedVideosState> build() async {
    _page = 0;
    final videos = await ref
        .read(savedVideosRepositoryProvider)
        .fetchSavedVideos(page: 0);
    return SavedVideosState(
      videos: videos,
      hasMore: videos.length == AppConstants.feedPageSize,
    );
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore || _isFetchingMore) return;
    _isFetchingMore = true;
    final nextPage = _page + 1;
    try {
      final more = await ref
          .read(savedVideosRepositoryProvider)
          .fetchSavedVideos(page: nextPage);
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

  /// Removing a video from this list happens immediately on unsave,
  /// rather than waiting for a refetch — the whole point of this screen
  /// is "things I've saved," so an unsaved item shouldn't linger.
  void removeLocal(String videoId) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        videos: current.videos.where((v) => v.id != videoId).toList(),
      ),
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final savedVideosProvider =
    AsyncNotifierProvider<SavedVideosNotifier, SavedVideosState>(
      SavedVideosNotifier.new,
    );

// ---------- Save/unsave action ----------

/// Same optimistic + rollback shape as LikeActions (Phase 7): update the
/// feed's in-memory VideoPost immediately, persist, revert on failure.
/// Also keeps the Saved Videos screen's own list in sync when an unsave
/// happens from *outside* that screen (e.g. from the feed's bookmark
/// icon while the Saved Videos screen is still mounted underneath).
class SaveActions {
  SaveActions(this._ref);
  final Ref _ref;

  Future<void> setSaved(String videoId, bool saved) async {
    _ref
        .read(feedProvider.notifier)
        .patchVideo(
          videoId,
          (post) => post.copyWith(
            isSavedByMe: saved,
            savesCount: post.savesCount + (saved ? 1 : -1),
          ),
        );
    if (!saved) {
      _ref.read(savedVideosProvider.notifier).removeLocal(videoId);
    }

    try {
      final repo = _ref.read(savedVideosRepositoryProvider);
      if (saved) {
        await repo.saveVideo(videoId);
      } else {
        await repo.unsaveVideo(videoId);
      }
    } catch (e) {
      _ref
          .read(feedProvider.notifier)
          .patchVideo(
            videoId,
            (post) => post.copyWith(
              isSavedByMe: !saved,
              savesCount: post.savesCount + (saved ? -1 : 1),
            ),
          );
      rethrow;
    }
  }
}

final saveActionsProvider = Provider((ref) => SaveActions(ref));
