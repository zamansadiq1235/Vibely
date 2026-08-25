import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/network/supabase_client_provider.dart';
import '../../../../core/router/route_names.dart';
import '../../domain/entities/friend_request_item.dart';
import '../providers/friends_provider.dart';

class FriendRequestsScreen extends ConsumerWidget {
  const FriendRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Friend Requests'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Received'),
              Tab(text: 'Sent'),
            ],
          ),
        ),
        body: const TabBarView(children: [_ReceivedTab(), _SentTab()]),
      ),
    );
  }
}

class _ReceivedTab extends ConsumerWidget {
  const _ReceivedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(receivedRequestsProvider);
    final client = ref.read(supabaseClientProvider);

    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) =>
          Center(child: Text('$err', style: context.textTheme.bodyMedium)),
      data: (state) {
        if (state.items.isEmpty) {
          return Center(
            child: Text(
              'No pending requests',
              style: context.textTheme.bodyMedium,
            ),
          );
        }
        return ListView.builder(
          itemCount: state.items.length,
          itemBuilder: (context, index) {
            final item = state.items[index];
            return _RequestTile(
              item: item,
              avatarUrl: item.profile.avatarPath == null
                  ? null
                  : client.storage
                        .from('avatars')
                        .getPublicUrl(item.profile.avatarPath!),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      try {
                        await ref
                            .read(friendRequestActionsProvider)
                            .reject(item.requestId);
                      } catch (e) {
                        if (context.mounted) {
                          context.showSnack('$e', isError: true);
                        }
                      }
                    },
                    child: const Text('Reject'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      try {
                        await ref
                            .read(friendRequestActionsProvider)
                            .accept(item.requestId);
                      } catch (e) {
                        if (context.mounted) {
                          context.showSnack('$e', isError: true);
                        }
                      }
                    },
                    child: const Text('Accept'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SentTab extends ConsumerWidget {
  const _SentTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(sentRequestsProvider);
    final client = ref.read(supabaseClientProvider);

    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) =>
          Center(child: Text('$err', style: context.textTheme.bodyMedium)),
      data: (state) {
        if (state.items.isEmpty) {
          return Center(
            child: Text(
              'No pending sent requests',
              style: context.textTheme.bodyMedium,
            ),
          );
        }
        return ListView.builder(
          itemCount: state.items.length,
          itemBuilder: (context, index) {
            final item = state.items[index];
            return _RequestTile(
              item: item,
              avatarUrl: item.profile.avatarPath == null
                  ? null
                  : client.storage
                        .from('avatars')
                        .getPublicUrl(item.profile.avatarPath!),
              trailing: OutlinedButton(
                onPressed: () async {
                  try {
                    await ref
                        .read(friendRequestActionsProvider)
                        .cancel(item.requestId);
                  } catch (e) {
                    if (context.mounted) context.showSnack('$e', isError: true);
                  }
                },
                child: const Text('Cancel'),
              ),
            );
          },
        );
      },
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.item,
    required this.avatarUrl,
    required this.trailing,
  });

  final FriendRequestItem item;
  final String? avatarUrl;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => context.push(
        RouteNames.userProfile.replaceFirst(':userId', item.profile.id),
      ),
      leading: CircleAvatar(
        backgroundColor: context.colors.surfaceContainerHighest,
        backgroundImage: avatarUrl != null
            ? CachedNetworkImageProvider(avatarUrl!)
            : null,
        child: avatarUrl == null ? const Icon(Icons.person_rounded) : null,
      ),
      title: Text(
        item.profile.fullName.isNotEmpty
            ? item.profile.fullName
            : '@${item.profile.username}',
      ),
      subtitle: Text('@${item.profile.username}'),
      trailing: trailing,
    );
  }
}
