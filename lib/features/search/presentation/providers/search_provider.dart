import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/supabase_client_provider.dart';
import '../../../auth/domain/entities/app_profile.dart';
import '../../../feed/domain/entities/video_post.dart';
import '../../../feed/presentation/providers/feed_provider.dart';
import '../../data/datasources/search_remote_data_source.dart';
import '../../data/repositories/search_repository_impl.dart';
import '../../domain/entities/hashtag_result.dart';
import '../../domain/repositories/search_repository.dart';

// ---------- Dependency injection ----------

final searchRemoteDataSourceProvider = Provider<SearchRemoteDataSource>((ref) {
  return SearchRemoteDataSource(ref.watch(supabaseClientProvider));
});

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepositoryImpl(
    ref.watch(searchRemoteDataSourceProvider),
    ref.watch(feedRemoteDataSourceProvider),
  );
});

// ---------- Debounced query ----------
// A plain Notifier<String> rather than the legacy `StateProvider` helper
// — same stable pattern already used for UploadDraftNotifier (Phase 5),
// so this doesn't depend on a separate part of the Riverpod API surface.

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String value) => state = value;
}

/// The debounced query — the search screen updates this from a Timer
/// (spec §22: "Implement debounced search") rather than on every
/// keystroke, so results providers below only refetch ~400ms after
/// typing pauses.
final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

// ---------- Generic paginated result state ----------

class SearchResultState<T> {
  const SearchResultState({required this.items, required this.hasMore});
  final List<T> items;
  final bool hasMore;

  SearchResultState<T> copyWith({List<T>? items, bool? hasMore}) {
    return SearchResultState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

// ---------- Users ----------
// AsyncNotifier + AsyncNotifierProvider.family — family arguments are passed
// to build(), which keeps the notifier compatible with Riverpod 3.
// CommentsNotifier/FollowersNotifier/FriendsListNotifier already use
// successfully, rather than the `AutoDispose`-prefixed variant.

class UserSearchNotifier extends AsyncNotifier<SearchResultState<AppProfile>> {
  UserSearchNotifier(this._query);

  final String _query;
  int _page = 0;
  bool _isFetchingMore = false;

  @override
  Future<SearchResultState<AppProfile>> build() async {
    _page = 0;
    if (_query.trim().isEmpty) {
      return const SearchResultState(items: [], hasMore: false);
    }
    final items = await ref
        .read(searchRepositoryProvider)
        .searchUsers(query: _query, page: 0);
    return SearchResultState(
      items: items,
      hasMore: items.length == AppConstants.searchPageSize,
    );
  }

  Future<void> loadMore(String query) async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore || _isFetchingMore) return;
    _isFetchingMore = true;
    final nextPage = _page + 1;
    try {
      final more = await ref
          .read(searchRepositoryProvider)
          .searchUsers(query: query, page: nextPage);
      _page = nextPage;
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...more],
          hasMore: more.length == AppConstants.searchPageSize,
        ),
      );
    } catch (_) {
    } finally {
      _isFetchingMore = false;
    }
  }
}

final userSearchProvider =
    AsyncNotifierProvider.family<
      UserSearchNotifier,
      SearchResultState<AppProfile>,
      String
    >(UserSearchNotifier.new);

// ---------- Videos ----------

class VideoSearchNotifier extends AsyncNotifier<SearchResultState<VideoPost>> {
  VideoSearchNotifier(this._query);

  final String _query;
  int _page = 0;
  bool _isFetchingMore = false;

  @override
  Future<SearchResultState<VideoPost>> build() async {
    _page = 0;
    if (_query.trim().isEmpty) {
      return const SearchResultState(items: [], hasMore: false);
    }
    final items = await ref
        .read(searchRepositoryProvider)
        .searchVideos(query: _query, page: 0);
    return SearchResultState(
      items: items,
      hasMore: items.length == AppConstants.searchPageSize,
    );
  }

  Future<void> loadMore(String query) async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore || _isFetchingMore) return;
    _isFetchingMore = true;
    final nextPage = _page + 1;
    try {
      final more = await ref
          .read(searchRepositoryProvider)
          .searchVideos(query: query, page: nextPage);
      _page = nextPage;
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...more],
          hasMore: more.length == AppConstants.searchPageSize,
        ),
      );
    } catch (_) {
    } finally {
      _isFetchingMore = false;
    }
  }
}

final videoSearchProvider =
    AsyncNotifierProvider.family<
      VideoSearchNotifier,
      SearchResultState<VideoPost>,
      String
    >(VideoSearchNotifier.new);

// ---------- Hashtags ----------

class HashtagSearchNotifier
    extends AsyncNotifier<SearchResultState<HashtagResult>> {
  HashtagSearchNotifier(this._query);

  final String _query;
  int _page = 0;
  bool _isFetchingMore = false;

  @override
  Future<SearchResultState<HashtagResult>> build() async {
    _page = 0;
    if (_query.trim().isEmpty) {
      return const SearchResultState(items: [], hasMore: false);
    }
    final items = await ref
        .read(searchRepositoryProvider)
        .searchHashtags(query: _query, page: 0);
    return SearchResultState(
      items: items,
      hasMore: items.length == AppConstants.searchPageSize,
    );
  }

  Future<void> loadMore(String query) async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore || _isFetchingMore) return;
    _isFetchingMore = true;
    final nextPage = _page + 1;
    try {
      final more = await ref
          .read(searchRepositoryProvider)
          .searchHashtags(query: query, page: nextPage);
      _page = nextPage;
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...more],
          hasMore: more.length == AppConstants.searchPageSize,
        ),
      );
    } catch (_) {
    } finally {
      _isFetchingMore = false;
    }
  }
}

final hashtagSearchProvider =
    AsyncNotifierProvider.family<
      HashtagSearchNotifier,
      SearchResultState<HashtagResult>,
      String
    >(HashtagSearchNotifier.new);
