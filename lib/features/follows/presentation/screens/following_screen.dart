import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/network/supabase_client_provider.dart';
import '../../../../core/router/route_names.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/follow_list_provider.dart';
import '../widgets/follow_list_tile.dart';

class FollowingScreen extends ConsumerStatefulWidget {
  const FollowingScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends ConsumerState<FollowingScreen> {
  final Set<String> _busyIds = {};

  Future<void> _toggle(String targetId, bool currentlyFollowing) async {
    setState(() => _busyIds.add(targetId));
    try {
      await ref
          .read(followListActionsProvider)
          .toggleFollow(
            targetUserId: targetId,
            currentlyFollowing: currentlyFollowing,
            listOwnerUserId: widget.userId,
            isFollowersList: false,
          );
    } catch (e) {
      if (mounted) context.showSnack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _busyIds.remove(targetId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(followingProvider(widget.userId));
    final viewerId = ref.watch(currentUserIdProvider);
    final client = ref.read(supabaseClientProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Following')),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) =>
            Center(child: Text('$err', style: context.textTheme.bodyMedium)),
        data: (state) {
          if (state.items.isEmpty) {
            return Center(
              child: Text(
                'Not following anyone yet',
                style: context.textTheme.bodyMedium,
              ),
            );
          }
          return NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) {
                ref
                    .read(followingProvider(widget.userId).notifier)
                    .loadMore(widget.userId);
              }
              return false;
            },
            child: ListView.builder(
              itemCount: state.items.length,
              itemBuilder: (context, index) {
                final item = state.items[index];
                final avatarUrl = item.profile.avatarPath == null
                    ? null
                    : client.storage
                          .from('avatars')
                          .getPublicUrl(item.profile.avatarPath!);
                return FollowListTile(
                  item: item,
                  avatarUrl: avatarUrl,
                  isViewerSelf: item.profile.id == viewerId,
                  isBusy: _busyIds.contains(item.profile.id),
                  onTap: () => context.push(
                    RouteNames.userProfile.replaceFirst(
                      ':userId',
                      item.profile.id,
                    ),
                  ),
                  onToggleFollow: () =>
                      _toggle(item.profile.id, item.isFollowedByViewer),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
