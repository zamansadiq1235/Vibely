/// Route path + name constants used by go_router.
/// Kept separate from app_router.dart so features can reference paths
/// without importing router configuration/build logic.
class RouteNames {
  RouteNames._();

  // Auth flow
  static const String splash = '/splash';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';
  static const String completeProfile = '/complete-profile';

  // Main shell (bottom nav)
  static const String home = '/home';
  static const String search = '/search';
  static const String create = '/create';
  static const String notifications = '/notifications';
  static const String profile = '/profile';

  // Video / social
  static const String videoPlayer = '/video/:videoId';
  static const String comments = '/video/:videoId/comments';
  static const String userProfile = '/user/:userId';
  static const String editProfile = '/profile/edit';

  static const String followers = '/user/:userId/followers';
  static const String following = '/user/:userId/following';
  static const String friends = '/user/:userId/friends';
  static const String friendRequests = '/friend-requests';

  static const String savedVideos = '/saved-videos';
  static const String repostedVideos = '/reposted-videos/:userId';
  static const String likedVideos = '/liked-videos';

  static const String settings = '/settings';
  static const String terms = '/terms';
  static const String privacyPolicy = '/privacy-policy';
}
