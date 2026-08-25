import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_client_provider.dart';
import '../../../feed/presentation/providers/feed_provider.dart';
import '../../data/datasources/like_remote_data_source.dart';
import '../../data/repositories/like_repository_impl.dart';
import '../../domain/repositories/like_repository.dart';

// ---------- Dependency injection ----------

final likeRemoteDataSourceProvider = Provider<LikeRemoteDataSource>((ref) {
  return LikeRemoteDataSource(ref.watch(supabaseClientProvider));
});

final likeRepositoryProvider = Provider<LikeRepository>((ref) {
  return LikeRepositoryImpl(ref.watch(likeRemoteDataSourceProvider));
});

/// Applies a like/unlike immediately to `feedProvider`'s in-memory list
/// (so the heart fills and the count changes with zero latency — the UI
/// requirement behind the double-tap animation), then persists it to
/// `video_likes`. If the write fails, the local change is reverted and
/// the caller is told, rather than leaving the UI showing a like that
/// was never actually saved.
///
/// `videos.likes_count` itself is never written from here — it's
/// maintained server-side by the trigger in migration 0003, so this
/// class's optimistic count bump is purely a *display* prediction that
/// self-corrects next time the feed refetches.
class LikeActions {
  LikeActions(this._ref);
  final Ref _ref;

  Future<void> setLiked(String videoId, bool liked) async {
    final feedNotifier = _ref.read(feedProvider.notifier);

    feedNotifier.patchVideo(
      videoId,
      (post) => post.copyWith(
        isLikedByMe: liked,
        likesCount: post.likesCount + (liked ? 1 : -1),
      ),
    );

    try {
      final repo = _ref.read(likeRepositoryProvider);
      if (liked) {
        await repo.likeVideo(videoId);
      } else {
        await repo.unlikeVideo(videoId);
      }
    } catch (e) {
      // Roll back the optimistic change.
      feedNotifier.patchVideo(
        videoId,
        (post) => post.copyWith(
          isLikedByMe: !liked,
          likesCount: post.likesCount + (liked ? -1 : 1),
        ),
      );
      rethrow;
    }
  }
}

final likeActionsProvider = Provider((ref) => LikeActions(ref));
