/// The `profiles` row for the signed-in user (or any user being viewed).
/// Deliberately separate from Supabase's `User` (auth identity) — this
/// is app-level profile data.
class AppProfile {
  const AppProfile({
    required this.id,
    required this.username,
    required this.fullName,
    required this.bio,
    this.avatarPath,
    required this.followersCount,
    required this.followingCount,
    required this.friendsCount,
    required this.likesCount,
  });

  final String id;
  final String username;
  final String fullName;
  final String bio;
  final String? avatarPath;
  final int followersCount;
  final int followingCount;
  final int friendsCount;
  final int likesCount;

  /// A profile is considered "complete" once the user has set a display
  /// name and an avatar — both collected on the Complete Profile screen.
  /// Username already exists from signup (auto-generated or chosen).
  bool get isComplete => fullName.trim().isNotEmpty && avatarPath != null;

  factory AppProfile.fromMap(Map<String, dynamic> map) {
    return AppProfile(
      id: map['id'] as String,
      username: map['username'] as String,
      fullName: (map['full_name'] as String?) ?? '',
      bio: (map['bio'] as String?) ?? '',
      avatarPath: map['avatar_path'] as String?,
      followersCount: (map['followers_count'] as int?) ?? 0,
      followingCount: (map['following_count'] as int?) ?? 0,
      friendsCount: (map['friends_count'] as int?) ?? 0,
      likesCount: (map['likes_count'] as int?) ?? 0,
    );
  }
}
