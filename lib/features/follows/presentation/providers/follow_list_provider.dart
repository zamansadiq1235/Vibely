import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/supabase_client_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../data/datasources/follow_list_remote_data_source.dart';
import '../../data/repositories/follow_list_repository_impl.dart';
import '../../domain/entities/follow_list_item.dart';
import '../../domain/repositories/follow_list_repository.dart';

// ---------- Dependency injection ----------

final followListRemoteDataSourceProvider = Provider<FollowListRemoteDataSource>(
  (ref) {
    return FollowListRemoteDataSource(ref.watch(supabaseClientProvider));
  },
);

final followListRepositoryProvider = Provider<FollowListRepository>((ref) {
  return FollowListRepositoryImpl(
    ref.watch(followListRemoteDataSourceProvider),
  );
});

// ---------- Shared list state ----------

class FollowListState {
  const FollowListState({required this.items, required this.hasMore});
  final List<FollowListItem> items;
  final bool hasMore;

  FollowListState copyWith({List<FollowListItem>? items, bool? hasMore}) {
    return FollowListState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class FollowersNotifier extends AsyncNotifier<FollowListState> {
  FollowersNotifier(this._userId);

  final String _userId;
  int _page = 0;
  bool _isFetchingMore = false;

  @override
  Future<FollowListState> build() async {
    _page = 0;
    final items = await ref
        .read(followListRepositoryProvider)
        .fetchFollowers(userId: _userId, page: 0);
    return FollowListState(
      items: items,
      hasMore: items.length == AppConstants.followListPageSize,
    );
  }

  Future<void> loadMore(String userId) async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore || _isFetchingMore) return;
    _isFetchingMore = true;
    final nextPage = _page + 1;
    try {
      final more = await ref
          .read(followListRepositoryProvider)
          .fetchFollowers(userId: userId, page: nextPage);
      _page = nextPage;
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...more],
          hasMore: more.length == AppConstants.followListPageSize,
        ),
      );
    } catch (_) {
    } finally {
      _isFetchingMore = false;
    }
  }

  void patch(String profileId, bool isFollowedByViewer) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        items: [
          for (final item in current.items)
            item.profile.id == profileId
                ? item.copyWith(isFollowedByViewer: isFollowedByViewer)
                : item,
        ],
      ),
    );
  }
}

final followersProvider =
    AsyncNotifierProvider.family<FollowersNotifier, FollowListState, String>(
      FollowersNotifier.new,
    );

class FollowingNotifier extends AsyncNotifier<FollowListState> {
  FollowingNotifier(this._userId);

  final String _userId;
  int _page = 0;
  bool _isFetchingMore = false;

  @override
  Future<FollowListState> build() async {
    _page = 0;
    final items = await ref
        .read(followListRepositoryProvider)
        .fetchFollowing(userId: _userId, page: 0);
    return FollowListState(
      items: items,
      hasMore: items.length == AppConstants.followListPageSize,
    );
  }

  Future<void> loadMore(String userId) async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore || _isFetchingMore) return;
    _isFetchingMore = true;
    final nextPage = _page + 1;
    try {
      final more = await ref
          .read(followListRepositoryProvider)
          .fetchFollowing(userId: userId, page: nextPage);
      _page = nextPage;
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...more],
          hasMore: more.length == AppConstants.followListPageSize,
        ),
      );
    } catch (_) {
    } finally {
      _isFetchingMore = false;
    }
  }

  void patch(String profileId, bool isFollowedByViewer) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        items: [
          for (final item in current.items)
            item.profile.id == profileId
                ? item.copyWith(isFollowedByViewer: isFollowedByViewer)
                : item,
        ],
      ),
    );
  }
}

final followingProvider =
    AsyncNotifierProvider.family<FollowingNotifier, FollowListState, String>(
      FollowingNotifier.new,
    );

// ---------- Follow/unfollow from within a list row ----------

/// Reuses `ProfileRepository.follow/unfollow` via `relationshipActionsProvider`
/// (Phase 4) rather than duplicating that mutation — this just also keeps
/// whichever Followers/Following list screens are currently mounted in
/// sync, since the same person can appear in more than one open list at
/// once (e.g. viewing A's followers while B's following list is still
/// cached underneath).
class FollowListActions {
  FollowListActions(this._ref);
  final Ref _ref;

  Future<void> toggleFollow({
    required String targetUserId,
    required bool currentlyFollowing,
    required String listOwnerUserId,
    required bool isFollowersList,
  }) async {
    // The two notifier types share a state shape but not a common public
    // `patch` interface. Keep the branch at the call-site so Dart does not
    // erase them to their AsyncNotifier base type.
    void patchList(bool isFollowedByViewer) {
      if (isFollowersList) {
        _ref
            .read(followersProvider(listOwnerUserId).notifier)
            .patch(targetUserId, isFollowedByViewer);
      } else {
        _ref
            .read(followingProvider(listOwnerUserId).notifier)
            .patch(targetUserId, isFollowedByViewer);
      }
    }

    patchList(!currentlyFollowing);

    try {
      await _ref
          .read(relationshipActionsProvider)
          .toggleFollow(targetUserId, currentlyFollowing: currentlyFollowing);
    } catch (e) {
      patchList(currentlyFollowing);
      rethrow;
    }
  }
}

final followListActionsProvider = Provider((ref) => FollowListActions(ref));
