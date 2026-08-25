// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/video_thumbnail_grid.dart';
import '../providers/search_provider.dart';
import '../widgets/hashtag_result_tile.dart';
import '../widgets/user_search_tile.dart';

/// Spec §22: search users/hashtags/videos with debounced input. The
/// text field updates `searchQueryProvider` after a short pause in
/// typing rather than on every keystroke, so results only refetch once
/// the user has actually stopped typing.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  Timer? _debounce;
  late final TabController _tabController;

  static const _debounceDuration = Duration(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      if (!mounted) return;
      ref.read(searchQueryProvider.notifier).state = value.trim();
    });
    setState(() {}); // refresh the clear (X) button's visibility
  }

  void _selectHashtag(String tag) {
    _controller.text = tag;
    _debounce?.cancel();
    ref.read(searchQueryProvider.notifier).state = tag;
    _tabController.animateTo(1); // jump to Videos tab
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: false,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: 'Search users, videos, hashtags',
            border: InputBorder.none,
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _controller.clear();
                      _debounce?.cancel();
                      ref.read(searchQueryProvider.notifier).state = '';
                      setState(() {});
                    },
                  ),
          ),
          onSubmitted: (v) {
            _debounce?.cancel();
            ref.read(searchQueryProvider.notifier).state = v.trim();
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Users'),
            Tab(text: 'Videos'),
            Tab(text: 'Hashtags'),
          ],
        ),
      ),
      body: query.isEmpty
          ? Center(
              child: Text(
                'Search for people, videos, or hashtags',
                style: context.textTheme.bodyMedium,
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _UsersTab(query: query),
                _VideosTab(query: query),
                _HashtagsTab(query: query, onSelect: _selectHashtag),
              ],
            ),
    );
  }
}

class _UsersTab extends ConsumerWidget {
  const _UsersTab({required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(userSearchProvider(query));

    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) =>
          Center(child: Text('$err', style: context.textTheme.bodyMedium)),
      data: (state) {
        if (state.items.isEmpty) {
          return Center(
            child: Text('No users found', style: context.textTheme.bodyMedium),
          );
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) {
              ref.read(userSearchProvider(query).notifier).loadMore(query);
            }
            return false;
          },
          child: ListView.builder(
            itemCount: state.items.length,
            itemBuilder: (context, index) =>
                UserSearchTile(profile: state.items[index]),
          ),
        );
      },
    );
  }
}

class _VideosTab extends ConsumerWidget {
  const _VideosTab({required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(videoSearchProvider(query));

    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) =>
          Center(child: Text('$err', style: context.textTheme.bodyMedium)),
      data: (state) {
        if (state.items.isEmpty) {
          return Center(
            child: Text('No videos found', style: context.textTheme.bodyMedium),
          );
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) {
              ref.read(videoSearchProvider(query).notifier).loadMore(query);
            }
            return false;
          },
          child: VideoThumbnailGrid(
            videos: state.items,
            onTap: (video) => context.showSnack(
              'Full video player screen is a future phase.',
            ),
          ),
        );
      },
    );
  }
}

class _HashtagsTab extends ConsumerWidget {
  const _HashtagsTab({required this.query, required this.onSelect});
  final String query;
  final void Function(String tag) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(hashtagSearchProvider(query));

    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) =>
          Center(child: Text('$err', style: context.textTheme.bodyMedium)),
      data: (state) {
        if (state.items.isEmpty) {
          return Center(
            child: Text(
              'No hashtags found',
              style: context.textTheme.bodyMedium,
            ),
          );
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) {
              ref.read(hashtagSearchProvider(query).notifier).loadMore(query);
            }
            return false;
          },
          child: ListView.builder(
            itemCount: state.items.length,
            itemBuilder: (context, index) {
              final tag = state.items[index];
              return HashtagResultTile(
                hashtag: tag,
                onTap: () => onSelect(tag.tag),
              );
            },
          ),
        );
      },
    );
  }
}
