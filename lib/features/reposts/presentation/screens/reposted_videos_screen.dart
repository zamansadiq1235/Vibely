import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/video_thumbnail_grid.dart';
import '../providers/repost_provider.dart';

class RepostedVideosScreen extends ConsumerWidget {
  const RepostedVideosScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repostsAsync = ref.watch(repostedVideosProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Reposts')),
      body: repostsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '$err',
              style: context.textTheme.bodyMedium,
              textAlign: TextAlign.center,
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
                    Icons.repeat_rounded,
                    size: 44,
                    color: context.colors.outline,
                  ),
                  const SizedBox(height: 10),
                  Text('No reposts yet', style: context.textTheme.bodyMedium),
                ],
              ),
            );
          }
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.pixels >
                  notification.metrics.maxScrollExtent - 400) {
                ref
                    .read(repostedVideosProvider(userId).notifier)
                    .loadMore(userId);
              }
              return false;
            },
            child: VideoThumbnailGrid(
              videos: state.videos,
              onTap: (video) => context.showSnack(
                "Full video player screen is a future phase — this opens @${video.username}'s video once it lands.",
              ),
            ),
          );
        },
      ),
    );
  }
}
