// ignore_for_file: unnecessary_underscores

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/route_names.dart';
import '../../../comments/presentation/widgets/comment_bottom_sheet.dart';
import '../../domain/entities/notification_item.dart';
import '../providers/notifications_provider.dart';
import '../widgets/notification_tile.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  void _handleTap(BuildContext context, WidgetRef ref, NotificationItem item) {
    ref.read(notificationsProvider.notifier).markAsRead(item.id);

    switch (item.kind) {
      case NotificationKind.comment:
      case NotificationKind.commentLike:
      case NotificationKind.commentReply:
        // These all have a videoId — open straight to the comments
        // thread rather than just the video, since that's the actual
        // content of the notification. initialCount is unknown here
        // (this screen doesn't have the video's live comments_count),
        // so the sheet's header undercounts until it's opened from the
        // feed directly — cosmetic only, the list itself is accurate.
        if (item.videoId != null) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: CommentBottomSheet(videoId: item.videoId!, initialCount: 0),
              ),
            ),
          );
        }
        break;
      case NotificationKind.friendRequest:
        context.push(RouteNames.friendRequests);
        break;
      case NotificationKind.videoLike:
      case NotificationKind.newFollower:
      case NotificationKind.friendRequestAccepted:
      case NotificationKind.repost:
        // No standalone video player screen yet (spec §41) to jump
        // straight to a liked/reposted video, so these go to the
        // actor's profile — still useful ("who liked/followed/reposted")
        // and consistent with how grid taps elsewhere handle the same gap.
        context.push(RouteNames.userProfile.replaceFirst(':userId', item.actorId));
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => ref.read(notificationsProvider.notifier).markAllAsRead(),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$err', style: context.textTheme.bodyMedium, textAlign: TextAlign.center),
          ),
        ),
        data: (state) {
          if (state.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 44, color: context.colors.outline),
                  const SizedBox(height: 10),
                  Text("You're all caught up", style: context.textTheme.bodyMedium),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(notificationsProvider),
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) {
                  ref.read(notificationsProvider.notifier).loadMore();
                }
                return false;
              },
              child: ListView.separated(
                itemCount: state.items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = state.items[index];
                  return NotificationTile(
                    key: ValueKey(item.id),
                    item: item,
                    onTap: () => _handleTap(context, ref, item),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}