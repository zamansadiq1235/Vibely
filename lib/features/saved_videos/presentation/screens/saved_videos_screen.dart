import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/video_thumbnail_grid.dart';
import '../providers/saved_videos_provider.dart';

class SavedVideosScreen extends ConsumerWidget {
  const SavedVideosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedVideosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Videos')),
      body: savedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$err',
                  style: context.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () =>
                      ref.read(savedVideosProvider.notifier).refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (state) {
          if (state.videos.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bookmark_border_rounded,
                    size: 44,
                    color: context.colors.outline,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No saved videos yet',
                    style: context.textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(savedVideosProvider.notifier).refresh(),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.pixels >
                    notification.metrics.maxScrollExtent - 400) {
                  ref.read(savedVideosProvider.notifier).loadMore();
                }
                return false;
              },
              child: VideoThumbnailGrid(
                videos: state.videos,
                onTap: (video) => context.showSnack(
                  "Full video player screen is a future phase — this opens @${video.username}'s video once it lands.",
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
