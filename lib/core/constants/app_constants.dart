/// Non-secret, compile-time constants for the Vibely app.
class AppConstants {
  AppConstants._();

  static const String appName = 'Vibely';
  static const String appTagline = 'Short videos. Real connections.';

  // Pagination
  static const int feedPageSize = 20;
  static const int commentsPageSize = 20;
  static const int repliesPageSize = 10;
  static const int followListPageSize = 30;
  static const int searchPageSize = 20;
  static const int notificationsPageSize = 30;

  // Video
  static const Duration minWatchDurationForView = Duration(seconds: 2);
  static const int maxVideoDurationSeconds = 180;
  static const int preloadWindow = 1; // number of videos ahead to preload

  // Storage buckets (must match Supabase Storage bucket names, see Phase 2)
  static const String avatarsBucket = 'avatars';
  static const String videosBucket = 'videos';
  static const String thumbnailsBucket = 'thumbnails';
}
