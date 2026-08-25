import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_client_provider.dart';
import '../../../auth/domain/entities/app_profile.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/profile_remote_data_source.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/relationship_info.dart';
import '../../domain/repositories/profile_repository.dart';

// ---------- Dependency injection ----------

final profileRemoteDataSourceProvider = Provider<ProfileRemoteDataSource>((
  ref,
) {
  return ProfileRemoteDataSource(ref.watch(supabaseClientProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl(
    ref.watch(profileRemoteDataSourceProvider),
    () => ref.read(authRepositoryProvider).currentUserId,
  );
});

/// The signed-in user's own id, or null. Widgets use this to decide
/// whether a profile screen is "mine" (show Edit Profile) or someone
/// else's (show Follow/Add Friend).
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authNotifierProvider).asData?.value.profile?.id ??
      ref.watch(authRepositoryProvider).currentUserId;
});

// ---------- Profile-by-id ----------

/// Fetches any user's profile row. Family keyed by userId so multiple
/// profiles (e.g. feed authors + the viewed profile) can be cached
/// independently. Call `ref.invalidate(profileProvider(userId))` after
/// an edit to refresh.
final profileProvider = FutureProvider.family<AppProfile, String>((
  ref,
  userId,
) {
  return ref.watch(profileRepositoryProvider).fetchProfile(userId);
});

/// Convenience: the signed-in user's own profile, kept in sync with
/// authNotifierProvider (which already refetches it on auth changes).
final myProfileProvider = Provider<AppProfile?>((ref) {
  return ref.watch(authNotifierProvider).asData?.value.profile;
});

// ---------- Relationship (follow/friend) state ----------

final relationshipProvider = FutureProvider.family<RelationshipInfo, String>((
  ref,
  targetUserId,
) {
  final currentUserId = ref.watch(currentUserIdProvider);
  if (currentUserId == null) return Future.value(RelationshipInfo.none);
  return ref
      .watch(profileRepositoryProvider)
      .fetchRelationship(
        currentUserId: currentUserId,
        targetUserId: targetUserId,
      );
});

/// Wraps the follow/friend mutations and refreshes both the relationship
/// state and the affected profiles' counts (followers_count etc, which
/// live server-side via triggers — see migration 0003) after each action.
class RelationshipActions {
  RelationshipActions(this._ref);
  final Ref _ref;

  ProfileRepository get _repo => _ref.read(profileRepositoryProvider);

  Future<void> toggleFollow(
    String targetUserId, {
    required bool currentlyFollowing,
  }) async {
    if (currentlyFollowing) {
      await _repo.unfollow(targetUserId);
    } else {
      await _repo.follow(targetUserId);
    }
    _refresh(targetUserId);
  }

  Future<void> sendFriendRequest(String targetUserId) async {
    await _repo.sendFriendRequest(targetUserId);
    _refresh(targetUserId);
  }

  Future<void> cancelFriendRequest(
    String requestId,
    String targetUserId,
  ) async {
    await _repo.cancelFriendRequest(requestId);
    _refresh(targetUserId);
  }

  Future<void> acceptFriendRequest(
    String requestId,
    String targetUserId,
  ) async {
    await _repo.acceptFriendRequest(requestId);
    _refresh(targetUserId);
  }

  Future<void> rejectFriendRequest(
    String requestId,
    String targetUserId,
  ) async {
    await _repo.rejectFriendRequest(requestId);
    _refresh(targetUserId);
  }

  Future<void> removeFriend(String requestId, String targetUserId) async {
    await _repo.removeFriend(requestId);
    _refresh(targetUserId);
  }

  void _refresh(String targetUserId) {
    _ref.invalidate(relationshipProvider(targetUserId));
    _ref.invalidate(profileProvider(targetUserId));
    final myId = _ref.read(currentUserIdProvider);
    if (myId != null) _ref.invalidate(profileProvider(myId));
  }
}

final relationshipActionsProvider = Provider((ref) => RelationshipActions(ref));
