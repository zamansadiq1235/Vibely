import '../../../auth/domain/entities/app_profile.dart';

/// One row in a Followers or Following list: the listed profile, plus
/// whether the *viewer* (current user) already follows them — spec
/// §23/§24 call this "Relationship Status." Friend status isn't shown
/// here; that's the dedicated Friends screen's job.
class FollowListItem {
  const FollowListItem({
    required this.profile,
    required this.isFollowedByViewer,
  });

  final AppProfile profile;
  final bool isFollowedByViewer;

  FollowListItem copyWith({bool? isFollowedByViewer}) {
    return FollowListItem(
      profile: profile,
      isFollowedByViewer: isFollowedByViewer ?? this.isFollowedByViewer,
    );
  }
}
