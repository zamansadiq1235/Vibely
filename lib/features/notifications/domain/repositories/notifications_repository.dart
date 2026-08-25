import '../entities/notification_item.dart';

abstract class NotificationsRepository {
  Future<List<NotificationItem>> fetchNotifications({required int page});

  Future<int> fetchUnreadCount();

  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead();

  /// Subscribes to new notification rows for the current user via
  /// Supabase Realtime (spec §26: "Use Supabase Realtime where
  /// appropriate"). Returns an unsubscribe function.
  Future<void Function()> subscribeToNew(void Function() onNewNotification);
}
