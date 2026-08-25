// ignore_for_file: unnecessary_underscores

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/network/supabase_client_provider.dart';
import '../../../../core/router/route_names.dart';
import '../../../feed/presentation/providers/feed_provider.dart';
import '../../../reposts/presentation/providers/repost_provider.dart';
import '../../../saved_videos/presentation/providers/saved_videos_provider.dart';
import '../../domain/entities/relationship_info.dart';
import '../providers/profile_provider.dart';
import '../widgets/profile_action_buttons.dart';
import '../widgets/profile_content_tabs.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_stats_row.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.userId});

  /// Null means "show the signed-in user's own profile".
  final String? userId;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _actionInFlight = false;

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() => _actionInFlight = true);
    try {
      await action();
    } catch (e) {
      if (mounted) context.showSnack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final targetUserId = widget.userId ?? currentUserId;

    if (targetUserId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isOwnProfile = targetUserId == currentUserId;
    final profileAsync = ref.watch(profileProvider(targetUserId));

    return Scaffold(
      appBar: AppBar(
        title: profileAsync.whenOrNull(data: (p) => Text('@${p.username}')),
        actions: [
          if (isOwnProfile)
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_rounded),
              tooltip: 'Friend Requests',
              onPressed: () => context.push(RouteNames.friendRequests),
            ),
          if (isOwnProfile)
            IconButton(
              icon: const Icon(Icons.bookmark_border_rounded),
              tooltip: 'Saved Videos',
              onPressed: () => context.push(RouteNames.savedVideos),
            ),
          if (isOwnProfile)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push(RouteNames.settings),
            ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Could not load this profile',
                  style: context.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '$err',
                  style: context.textTheme.labelSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () =>
                      ref.invalidate(profileProvider(targetUserId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (profile) {
          final avatarUrl = profile.avatarPath == null
              ? null
              : ref
                    .read(supabaseClientProvider)
                    .storage
                    .from(AppConstants.avatarsBucket)
                    .getPublicUrl(profile.avatarPath!);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(profileProvider(targetUserId));
              ref.invalidate(userVideosProvider(targetUserId));
              ref.invalidate(repostedVideosProvider(targetUserId));
              if (isOwnProfile) {
                ref.invalidate(savedVideosProvider);
              }
              if (!isOwnProfile) {
                ref.invalidate(relationshipProvider(targetUserId));
              }
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: [
                ProfileHeader(profile: profile, avatarUrl: avatarUrl),
                const SizedBox(height: 16),
                ProfileStatsRow(
                  following: profile.followingCount,
                  followers: profile.followersCount,
                  likes: profile.likesCount,
                  friends: profile.friendsCount,
                  onTapFollowing: () => context.push(
                    RouteNames.following.replaceFirst(':userId', targetUserId),
                  ),
                  onTapFollowers: () => context.push(
                    RouteNames.followers.replaceFirst(':userId', targetUserId),
                  ),
                  onTapFriends: () => context.push(
                    RouteNames.friends.replaceFirst(':userId', targetUserId),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: isOwnProfile
                      ? ProfileActionButtons(
                          isOwnProfile: true,
                          relationship: RelationshipInfo.none,
                          isBusy: false,
                          onEditProfile: () =>
                              context.push(RouteNames.editProfile),
                        )
                      : _buildRelationshipActions(context, targetUserId),
                ),
                const SizedBox(height: 24),
                ProfileContentTabs(
                  isOwnProfile: isOwnProfile,
                  userId: targetUserId,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRelationshipActions(BuildContext context, String targetUserId) {
    final relAsync = ref.watch(relationshipProvider(targetUserId));
    final actions = ref.read(relationshipActionsProvider);

    return relAsync.when(
      loading: () => const SizedBox(
        height: 40,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (relationship) => ProfileActionButtons(
        isOwnProfile: false,
        relationship: relationship,
        isBusy: _actionInFlight,
        onToggleFollow: () => _runAction(
          () => actions.toggleFollow(
            targetUserId,
            currentlyFollowing: relationship.isFollowing,
          ),
        ),
        onSendFriendRequest: () =>
            _runAction(() => actions.sendFriendRequest(targetUserId)),
        onCancelFriendRequest: relationship.friendRequestId == null
            ? null
            : () => _runAction(
                () => actions.cancelFriendRequest(
                  relationship.friendRequestId!,
                  targetUserId,
                ),
              ),
        onAcceptFriendRequest: relationship.friendRequestId == null
            ? null
            : () => _runAction(
                () => actions.acceptFriendRequest(
                  relationship.friendRequestId!,
                  targetUserId,
                ),
              ),
        onRemoveFriend: relationship.friendRequestId == null
            ? null
            : () => _runAction(
                () => actions.removeFriend(
                  relationship.friendRequestId!,
                  targetUserId,
                ),
              ),
      ),
    );
  }
}
