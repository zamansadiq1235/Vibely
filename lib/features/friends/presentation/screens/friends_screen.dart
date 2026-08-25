import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/network/supabase_client_provider.dart';
import '../../../../core/router/route_names.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/friends_provider.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  Future<void> _removeFriend(String requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove friend?'),
        content: const Text(
          'You can send a new friend request later if you change your mind.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(friendRequestActionsProvider)
          .removeFriend(requestId, widget.userId);
    } catch (e) {
      if (mounted) context.showSnack('$e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(friendsListProvider(widget.userId));
    final isOwnList = ref.watch(currentUserIdProvider) == widget.userId;
    final client = ref.read(supabaseClientProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) =>
            Center(child: Text('$err', style: context.textTheme.bodyMedium)),
        data: (state) {
          if (state.items.isEmpty) {
            return Center(
              child: Text(
                'No friends yet',
                style: context.textTheme.bodyMedium,
              ),
            );
          }
          return NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) {
                ref
                    .read(friendsListProvider(widget.userId).notifier)
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
                return ListTile(
                  onTap: () => context.push(
                    RouteNames.userProfile.replaceFirst(
                      ':userId',
                      item.profile.id,
                    ),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: context.colors.surfaceContainerHighest,
                    backgroundImage: avatarUrl != null
                        ? CachedNetworkImageProvider(avatarUrl)
                        : null,
                    child: avatarUrl == null
                        ? const Icon(Icons.person_rounded)
                        : null,
                  ),
                  title: Text(
                    item.profile.fullName.isNotEmpty
                        ? item.profile.fullName
                        : '@${item.profile.username}',
                  ),
                  subtitle: Text('@${item.profile.username}'),
                  trailing: isOwnList
                      ? OutlinedButton(
                          onPressed: () => _removeFriend(item.friendRequestId),
                          child: const Text('Friends'),
                        )
                      : null,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
