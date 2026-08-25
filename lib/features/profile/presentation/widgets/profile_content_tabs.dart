// ignore_for_file: unnecessary_underscores

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/video_thumbnail_grid.dart';
import '../../../feed/presentation/providers/feed_provider.dart';
import '../../../reposts/presentation/providers/repost_provider.dart';
import '../../../saved_videos/presentation/providers/saved_videos_provider.dart';

/// Spec §5: Videos / Reposts / Saved / Liked tabs on a profile.
class ProfileContentTabs extends ConsumerWidget {
  const ProfileContentTabs({
    super.key,
    required this.isOwnProfile,
    required this.userId,
  });

  final bool isOwnProfile;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabCount = isOwnProfile ? 4 : 3;

    return DefaultTabController(
      length: tabCount,
      child: Column(
        children: [
          TabBar(
            tabs: [
              const Tab(icon: Icon(Icons.grid_on_rounded), text: 'Videos'),
              const Tab(icon: Icon(Icons.repeat_rounded), text: 'Reposts'),
              if (isOwnProfile)
                const Tab(
                  icon: Icon(Icons.bookmark_border_rounded),
                  text: 'Saved',
                ),
              const Tab(
                icon: Icon(Icons.favorite_border_rounded),
                text: 'Liked',
              ),
            ],
          ),
          SizedBox(
            height: 450,
            child: TabBarView(
              children: [
                _VideosTab(userId: userId, isOwnProfile: isOwnProfile),
                _RepostsTab(userId: userId, isOwnProfile: isOwnProfile),
                if (isOwnProfile) const _SavedTab(),
                _EmptyGrid(
                  icon: Icons.favorite_border_rounded,
                  message: isOwnProfile
                      ? 'Videos you like will appear here'
                      : 'No liked videos',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VideosTab extends ConsumerWidget {
  const _VideosTab({required this.userId, required this.isOwnProfile});

  final String userId;
  final bool isOwnProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosAsync = ref.watch(userVideosProvider(userId));

    return videosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const _EmptyGrid(
        icon: Icons.error_outline_rounded,
        message: 'Could not load videos',
      ),
      data: (state) {
        if (state.videos.isEmpty) {
          return _EmptyGrid(
            icon: Icons.videocam_off_rounded,
            message: isOwnProfile
                ? "You haven't posted any videos yet"
                : 'No videos yet',
          );
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) {
              ref.read(userVideosProvider(userId).notifier).loadMore(userId);
            }
            return false;
          },
          child: VideoThumbnailGrid(
            videos: state.videos,
            onTap: (video) => context.showSnack(
              'Playing video: ${video.caption.isNotEmpty ? video.caption : video.id}',
            ),
          ),
        );
      },
    );
  }
}

class _SavedTab extends ConsumerWidget {
  const _SavedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedVideosProvider);

    return savedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const _EmptyGrid(
        icon: Icons.error_outline_rounded,
        message: 'Could not load saved videos',
      ),
      data: (state) {
        if (state.videos.isEmpty) {
          return const _EmptyGrid(
            icon: Icons.bookmark_border_rounded,
            message: "You haven't saved any videos yet",
          );
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) {
              ref.read(savedVideosProvider.notifier).loadMore();
            }
            return false;
          },
          child: VideoThumbnailGrid(
            videos: state.videos,
            onTap: (video) => context.showSnack(
              'Playing video: ${video.caption.isNotEmpty ? video.caption : video.id}',
            ),
          ),
        );
      },
    );
  }
}

class _RepostsTab extends ConsumerWidget {
  const _RepostsTab({required this.userId, required this.isOwnProfile});

  final String userId;
  final bool isOwnProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repostsAsync = ref.watch(repostedVideosProvider(userId));

    return repostsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const _EmptyGrid(
        icon: Icons.error_outline_rounded,
        message: 'Could not load reposts',
      ),
      data: (state) {
        if (state.videos.isEmpty) {
          return _EmptyGrid(
            icon: Icons.repeat_rounded,
            message: isOwnProfile
                ? "You haven't reposted anything"
                : 'No reposts yet',
          );
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) {
              ref
                  .read(repostedVideosProvider(userId).notifier)
                  .loadMore(userId);
            }
            return false;
          },
          child: VideoThumbnailGrid(
            videos: state.videos,
            onTap: (video) => context.showSnack(
              'Playing video: ${video.caption.isNotEmpty ? video.caption : video.id}',
            ),
          ),
        );
      },
    );
  }
}

class _EmptyGrid extends StatelessWidget {
  const _EmptyGrid({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: context.colors.outline),
          const SizedBox(height: 10),
          Text(
            message,
            style: context.textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
