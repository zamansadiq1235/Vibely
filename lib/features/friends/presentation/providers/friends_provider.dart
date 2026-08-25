// ignore_for_file: unused_field

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/supabase_client_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../data/datasources/friends_remote_data_source.dart';
import '../../data/repositories/friends_repository_impl.dart';
import '../../domain/entities/friend_list_item.dart';
import '../../domain/entities/friend_request_item.dart';
import '../../domain/repositories/friends_repository.dart';

// ---------- Dependency injection ----------

final friendsRemoteDataSourceProvider = Provider<FriendsRemoteDataSource>((
  ref,
) {
  return FriendsRemoteDataSource(ref.watch(supabaseClientProvider));
});

final friendsRepositoryProvider = Provider<FriendsRepository>((ref) {
  return FriendsRepositoryImpl(ref.watch(friendsRemoteDataSourceProvider));
});

// ---------- Friends list (per user, viewable on any profile) ----------

class FriendsListState {
  const FriendsListState({required this.items, required this.hasMore});
  final List<FriendListItem> items;
  final bool hasMore;

  FriendsListState copyWith({List<FriendListItem>? items, bool? hasMore}) {
    return FriendsListState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class FriendsListNotifier extends AsyncNotifier<FriendsListState> {
  FriendsListNotifier(this._userId);

  final String _userId;
  int _page = 0;
  bool _isFetchingMore = false;

  @override
  Future<FriendsListState> build() async {
    _page = 0;
    final items = await ref
        .read(friendsRepositoryProvider)
        .fetchFriends(userId: _userId, page: 0);
    return FriendsListState(
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
          .read(friendsRepositoryProvider)
          .fetchFriends(userId: userId, page: nextPage);
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

  void removeLocal(String friendRequestId) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        items: current.items
            .where((f) => f.friendRequestId != friendRequestId)
            .toList(),
      ),
    );
  }
}

final friendsListProvider =
    AsyncNotifierProvider.family<FriendsListNotifier, FriendsListState, String>(
      FriendsListNotifier.new,
    );

// ---------- Friend requests (received / sent, current user only) ----------

class FriendRequestsState {
  const FriendRequestsState({required this.items, required this.hasMore});
  final List<FriendRequestItem> items;
  final bool hasMore;

  FriendRequestsState copyWith({
    List<FriendRequestItem>? items,
    bool? hasMore,
  }) {
    return FriendRequestsState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class ReceivedRequestsNotifier extends AsyncNotifier<FriendRequestsState> {
  int _page = 0;

  @override
  Future<FriendRequestsState> build() async {
    _page = 0;
    final items = await ref
        .read(friendsRepositoryProvider)
        .fetchReceivedRequests(page: 0);
    return FriendRequestsState(
      items: items,
      hasMore: items.length == AppConstants.followListPageSize,
    );
  }

  void removeLocal(String requestId) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        items: current.items.where((r) => r.requestId != requestId).toList(),
      ),
    );
  }
}

final receivedRequestsProvider =
    AsyncNotifierProvider<ReceivedRequestsNotifier, FriendRequestsState>(
      ReceivedRequestsNotifier.new,
    );

class SentRequestsNotifier extends AsyncNotifier<FriendRequestsState> {
  int _page = 0;

  @override
  Future<FriendRequestsState> build() async {
    _page = 0;
    final items = await ref
        .read(friendsRepositoryProvider)
        .fetchSentRequests(page: 0);
    return FriendRequestsState(
      items: items,
      hasMore: items.length == AppConstants.followListPageSize,
    );
  }

  void removeLocal(String requestId) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        items: current.items.where((r) => r.requestId != requestId).toList(),
      ),
    );
  }
}

final sentRequestsProvider =
    AsyncNotifierProvider<SentRequestsNotifier, FriendRequestsState>(
      SentRequestsNotifier.new,
    );

// ---------- Actions ----------

/// Reuses `ProfileRepository`'s accept/reject/cancel/removeFriend
/// (built in Phase 4 for the single-profile Follow/Add Friend button)
/// rather than duplicating those mutations, and additionally removes
/// the affected row from whichever request/friends list is showing it.
class FriendRequestActions {
  FriendRequestActions(this._ref);
  final Ref _ref;

  Future<void> accept(String requestId) async {
    await _ref.read(profileRepositoryProvider).acceptFriendRequest(requestId);
    _ref.read(receivedRequestsProvider.notifier).removeLocal(requestId);
  }

  Future<void> reject(String requestId) async {
    await _ref.read(profileRepositoryProvider).rejectFriendRequest(requestId);
    _ref.read(receivedRequestsProvider.notifier).removeLocal(requestId);
  }

  Future<void> cancel(String requestId) async {
    await _ref.read(profileRepositoryProvider).cancelFriendRequest(requestId);
    _ref.read(sentRequestsProvider.notifier).removeLocal(requestId);
  }

  Future<void> removeFriend(String requestId, String friendsListOwnerId) async {
    await _ref.read(profileRepositoryProvider).removeFriend(requestId);
    _ref
        .read(friendsListProvider(friendsListOwnerId).notifier)
        .removeLocal(requestId);
  }
}

final friendRequestActionsProvider = Provider(
  (ref) => FriendRequestActions(ref),
);
