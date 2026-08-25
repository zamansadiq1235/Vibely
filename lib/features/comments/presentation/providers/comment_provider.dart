import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/supabase_client_provider.dart';
import '../../../feed/presentation/providers/feed_provider.dart';
import '../../data/datasources/comment_remote_data_source.dart';
import '../../data/repositories/comment_repository_impl.dart';
import '../../domain/entities/comment.dart';
import '../../domain/repositories/comment_repository.dart';

// ---------- Dependency injection ----------

final commentRemoteDataSourceProvider = Provider<CommentRemoteDataSource>((
  ref,
) {
  return CommentRemoteDataSource(ref.watch(supabaseClientProvider));
});

final commentRepositoryProvider = Provider<CommentRepository>((ref) {
  return CommentRepositoryImpl(
    ref.watch(commentRemoteDataSourceProvider),
    ref.watch(supabaseClientProvider),
  );
});

// ---------- Paginated list state (shared shape for comments + replies) ----------

class CommentListState {
  const CommentListState({required this.items, required this.hasMore});

  final List<Comment> items;
  final bool hasMore;

  CommentListState copyWith({List<Comment>? items, bool? hasMore}) {
    return CommentListState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// Top-level comments for a video, keyed by videoId.
class CommentsNotifier extends AsyncNotifier<CommentListState> {
  CommentsNotifier(this._videoId);

  final String _videoId;
  int _page = 0;
  bool _isFetchingMore = false;

  @override
  Future<CommentListState> build() async {
    _page = 0;
    final items = await ref
        .read(commentRepositoryProvider)
        .fetchComments(videoId: _videoId, page: 0);
    return CommentListState(
      items: items,
      hasMore: items.length == AppConstants.commentsPageSize,
    );
  }

  Future<void> loadMore(String videoId) async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore || _isFetchingMore) return;
    _isFetchingMore = true;
    final nextPage = _page + 1;
    try {
      final more = await ref
          .read(commentRepositoryProvider)
          .fetchComments(videoId: videoId, page: nextPage);
      _page = nextPage;
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...more],
          hasMore: more.length == AppConstants.commentsPageSize,
        ),
      );
    } catch (_) {
      // Leave as-is; scrolling further retries.
    } finally {
      _isFetchingMore = false;
    }
  }

  void prepend(Comment comment) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(items: [comment, ...current.items]));
  }

  void remove(String commentId) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        items: current.items.where((c) => c.id != commentId).toList(),
      ),
    );
  }

  void patch(String commentId, Comment Function(Comment) updater) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        items: [
          for (final c in current.items) c.id == commentId ? updater(c) : c,
        ],
      ),
    );
  }
}

final commentsProvider =
    AsyncNotifierProvider.family<CommentsNotifier, CommentListState, String>(
      CommentsNotifier.new,
    );

/// Replies to a single top-level comment, keyed by that comment's id.
/// Loaded on demand ("View replies") rather than eagerly with the parent
/// comment list, per spec §11's pagination requirement.
class RepliesNotifier extends AsyncNotifier<CommentListState> {
  RepliesNotifier(this._parentId);

  final String _parentId;
  int _page = 0;
  bool _isFetchingMore = false;

  @override
  Future<CommentListState> build() async {
    _page = 0;
    final items = await ref
        .read(commentRepositoryProvider)
        .fetchReplies(parentId: _parentId, page: 0);
    return CommentListState(
      items: items,
      hasMore: items.length == AppConstants.repliesPageSize,
    );
  }

  Future<void> loadMore(String parentId) async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore || _isFetchingMore) return;
    _isFetchingMore = true;
    final nextPage = _page + 1;
    try {
      final more = await ref
          .read(commentRepositoryProvider)
          .fetchReplies(parentId: parentId, page: nextPage);
      _page = nextPage;
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...more],
          hasMore: more.length == AppConstants.repliesPageSize,
        ),
      );
    } catch (_) {
    } finally {
      _isFetchingMore = false;
    }
  }

  void append(Comment reply) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(items: [...current.items, reply]));
  }

  void remove(String commentId) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        items: current.items.where((c) => c.id != commentId).toList(),
      ),
    );
  }

  void patch(String commentId, Comment Function(Comment) updater) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        items: [
          for (final c in current.items) c.id == commentId ? updater(c) : c,
        ],
      ),
    );
  }
}

final repliesProvider =
    AsyncNotifierProvider.family<RepliesNotifier, CommentListState, String>(
      RepliesNotifier.new,
    );

// ---------- Coordinated actions ----------

/// Wraps add/delete/like so a single call updates every list that needs
/// to know about it: the relevant comments/replies list, the parent
/// comment's replies_count (for a reply), and the video's comments_count
/// shown back in the feed — all optimistically, with rollback on failure
/// for the like/unlike path (add/delete surface their error and let the
/// caller decide whether to retry, since silently "un-posting" a comment
/// the user just typed would be more surprising than useful).
class CommentActions {
  CommentActions(this._ref);
  final Ref _ref;

  Future<void> addComment({
    required String videoId,
    required String content,
    String? parentId,
  }) async {
    final comment = await _ref
        .read(commentRepositoryProvider)
        .addComment(videoId: videoId, content: content, parentId: parentId);

    if (parentId == null) {
      _ref.read(commentsProvider(videoId).notifier).prepend(comment);
    } else {
      _ref.read(repliesProvider(parentId).notifier).append(comment);
      _ref
          .read(commentsProvider(videoId).notifier)
          .patch(parentId, (c) => c.copyWith(repliesCount: c.repliesCount + 1));
    }

    _ref
        .read(feedProvider.notifier)
        .patchVideo(
          videoId,
          (post) => post.copyWith(commentsCount: post.commentsCount + 1),
        );
  }

  Future<void> deleteComment(Comment comment) async {
    await _ref.read(commentRepositoryProvider).deleteComment(comment.id);

    if (comment.isReply) {
      _ref.read(repliesProvider(comment.parentId!).notifier).remove(comment.id);
      _ref
          .read(commentsProvider(comment.videoId).notifier)
          .patch(
            comment.parentId!,
            (c) => c.copyWith(
              repliesCount: c.repliesCount > 0 ? c.repliesCount - 1 : 0,
            ),
          );
    } else {
      _ref.read(commentsProvider(comment.videoId).notifier).remove(comment.id);
    }

    _ref
        .read(feedProvider.notifier)
        .patchVideo(
          comment.videoId,
          (post) => post.copyWith(
            commentsCount: post.commentsCount > 0 ? post.commentsCount - 1 : 0,
          ),
        );
  }

  Future<void> setLiked(Comment comment, bool liked) async {
    void apply(bool value) {
      Comment updater(Comment c) => c.copyWith(
        isLikedByMe: value,
        likesCount: c.likesCount + (value ? 1 : -1),
      );
      if (comment.isReply) {
        _ref
            .read(repliesProvider(comment.parentId!).notifier)
            .patch(comment.id, updater);
      } else {
        _ref
            .read(commentsProvider(comment.videoId).notifier)
            .patch(comment.id, updater);
      }
    }

    apply(liked);
    try {
      final repo = _ref.read(commentRepositoryProvider);
      if (liked) {
        await repo.likeComment(comment.id);
      } else {
        await repo.unlikeComment(comment.id);
      }
    } catch (e) {
      apply(!liked); // rollback
      rethrow;
    }
  }
}

final commentActionsProvider = Provider((ref) => CommentActions(ref));
