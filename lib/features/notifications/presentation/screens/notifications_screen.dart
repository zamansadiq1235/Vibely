// ignore_for_file: unnecessary_underscores

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../comments/presentation/widgets/comment_bottom_sheet.dart';
import '../../domain/entities/notification_item.dart';
import '../providers/notifications_provider.dart';
import '../widgets/notification_tile.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  void _handleTap(BuildContext context, WidgetRef ref, NotificationItem item) {
    final notifier = ref.read(notificationsProvider.notifier);

    // In selection mode a tap just toggles the checkbox — navigation is
    // intentionally disabled so users don't teleport mid-selection.
    if (ref.read(notificationsProvider).asData?.value.isSelectionMode ??
        false) {
      notifier.toggleSelection(item.id);
      return;
    }

    notifier.markAsRead(item.id);

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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: CommentBottomSheet(
                  videoId: item.videoId!,
                  initialCount: 0,
                ),
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
        context.push(
          RouteNames.userProfile.replaceFirst(':userId', item.actorId),
        );
        break;
    }
  }

  /// Asks for confirmation, then runs the optimistic delete from the
  /// Riverpod notifier. The dialog itself is deliberately destructive-red
  /// accented so a mis-tap can't wipe selections silently.
  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final count =
        ref.read(notificationsProvider).asData?.value.selectedIds.length ?? 0;
    if (count == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogContext.isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete notifications?'),
        content: Text(
          count == 1
              ? 'This notification will be permanently removed.'
              : 'These $count notifications will be permanently removed.',
          style: dialogContext.textTheme.bodyMedium,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(false),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => dialogContext.pop(true),
            icon: const Icon(Icons.delete_rounded, size: 18),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(notificationsProvider.notifier).deleteSelected();
      if (context.mounted) context.showSnack('Deleted');
    } catch (_) {
      if (context.mounted) {
        context.showSnack("Couldn't delete. Please try again.", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final selectionCount =
        notificationsAsync.asData?.value.selectedIds.length ?? 0;
    final inSelection =
        notificationsAsync.asData?.value.isSelectionMode ?? false;

    return PopScope(
      canPop: !inSelection,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && inSelection) {
          ref.read(notificationsProvider.notifier).exitSelectionMode();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: inSelection
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Exit selection',
                  onPressed: () => ref
                      .read(notificationsProvider.notifier)
                      .exitSelectionMode(),
                )
              : null,
          title: inSelection
              ? Text('$selectionCount selected')
              : const Text('Notifications'),
          actions: [
            if (inSelection)
              IconButton(
                icon: const Icon(Icons.select_all_rounded),
                tooltip: 'Select all',
                onPressed: () =>
                    ref.read(notificationsProvider.notifier).selectAll(),
              )
            else
              TextButton(
                onPressed: () =>
                    ref.read(notificationsProvider.notifier).markAllAsRead(),
                child: const Text('Mark all read'),
              ),
            if (inSelection)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton.filledTonal(
                  tooltip: 'Delete selected',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.error.withValues(alpha: 0.15),
                    foregroundColor: AppColors.error,
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _confirmAndDelete(context, ref),
                ),
              ),
          ],
        ),
        body: notificationsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
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
            if (state.items.isEmpty) {
              return _EmptyNotifications();
            }
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => ref.invalidate(notificationsProvider),
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) {
                    ref.read(notificationsProvider.notifier).loadMore();
                  }
                  return false;
                },
                child: ListView.separated(
                  padding: const EdgeInsets.only(top: 6, bottom: 90),
                  itemCount: state.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 2),
                  itemBuilder: (context, index) {
                    final item = state.items[index];
                    return NotificationTile(
                      key: ValueKey(item.id),
                      item: item,
                      isSelected: state.selectedIds.contains(item.id),
                      selectionMode: state.isSelectionMode,
                      onTap: () => _handleTap(context, ref, item),
                      onLongPress: () => ref
                          .read(notificationsProvider.notifier)
                          .enterSelectionMode(item.id),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.30),
                  AppColors.accent.withValues(alpha: 0.30),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 44,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text("You're all caught up", style: context.textTheme.bodyLarge),
          const SizedBox(height: 4),
          Text(
            'New activity will appear here.',
            style: context.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
