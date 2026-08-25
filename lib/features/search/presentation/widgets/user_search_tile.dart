// ignore_for_file: unnecessary_underscores

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/network/supabase_client_provider.dart';
import '../../../../core/router/route_names.dart';
import '../../../auth/domain/entities/app_profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../profile/presentation/widgets/profile_action_buttons.dart';

/// Reuses `ProfileActionButtons` (Phase 4) so a search result's Follow/
/// Add Friend button behaves identically to the one on the full profile
/// screen — same states, same actions, same optimistic + rollback
/// handling — rather than a third copy of that logic.
class UserSearchTile extends ConsumerStatefulWidget {
  const UserSearchTile({super.key, required this.profile});

  final AppProfile profile;

  @override
  ConsumerState<UserSearchTile> createState() => _UserSearchTileState();
}

class _UserSearchTileState extends ConsumerState<UserSearchTile> {
  bool _isBusy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _isBusy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) context.showSnack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.read(supabaseClientProvider);
    final avatarUrl = widget.profile.avatarPath == null
        ? null
        : client.storage
              .from(AppConstants.avatarsBucket)
              .getPublicUrl(widget.profile.avatarPath!);
    final currentUserId = ref.watch(currentUserIdProvider);
    final isSelf = widget.profile.id == currentUserId;
    final relAsync = isSelf
        ? null
        : ref.watch(relationshipProvider(widget.profile.id));
    final actions = ref.read(relationshipActionsProvider);

    return Card(
      child: Column(
        children: [
          ListTile(
            onTap: () => context.push(
              RouteNames.userProfile.replaceFirst(':userId', widget.profile.id),
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
              widget.profile.fullName.isNotEmpty
                  ? widget.profile.fullName
                  : '@${widget.profile.username}',
            ),
            subtitle: Text(
              '@${widget.profile.username} · ${_formatCount(widget.profile.followersCount)} followers',
            ),
          ),
          if (!isSelf && relAsync != null)
            relAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  height: 36,
                  child: Center(
                    child: SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (relationship) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: ProfileActionButtons(
                  isOwnProfile: false,
                  relationship: relationship,
                  isBusy: _isBusy,
                  onToggleFollow: () => _run(
                    () => actions.toggleFollow(
                      widget.profile.id,
                      currentlyFollowing: relationship.isFollowing,
                    ),
                  ),
                  onSendFriendRequest: () =>
                      _run(() => actions.sendFriendRequest(widget.profile.id)),
                  onCancelFriendRequest: relationship.friendRequestId == null
                      ? null
                      : () => _run(
                          () => actions.cancelFriendRequest(
                            relationship.friendRequestId!,
                            widget.profile.id,
                          ),
                        ),
                  onAcceptFriendRequest: relationship.friendRequestId == null
                      ? null
                      : () => _run(
                          () => actions.acceptFriendRequest(
                            relationship.friendRequestId!,
                            widget.profile.id,
                          ),
                        ),
                  onRemoveFriend: relationship.friendRequestId == null
                      ? null
                      : () => _run(
                          () => actions.removeFriend(
                            relationship.friendRequestId!,
                            widget.profile.id,
                          ),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _formatCount(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }
}
