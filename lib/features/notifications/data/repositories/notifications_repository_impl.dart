import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/notification_item.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../datasources/notifications_remote_data_source.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl(this._dataSource, this._client);

  final NotificationsRemoteDataSource _dataSource;
  final SupabaseClient _client;

  @override
  Future<List<NotificationItem>> fetchNotifications({required int page}) async {
    final rows = await _dataSource.fetchNotificationRows(page: page);
    return rows.map((row) {
      final actor = row['actor'] as Map<String, dynamic>?;
      return NotificationItem(
        id: row['id'] as String,
        kind: NotificationKind.fromDb(row['type'] as String),
        actorId: row['actor_id'] as String? ?? '',
        actorUsername: actor?['username'] as String? ?? 'someone',
        actorAvatarUrl: _dataSource.resolveAvatarUrl(
          actor?['avatar_path'] as String?,
        ),
        videoId:
            (row['video_id'] ?? row['entity_id'] ?? row['edentity_id'])
                as String?,
        commentId:
            (row['comment_id'] ?? row['entity_id'] ?? row['edentity_id'])
                as String?,
        friendRequestId:
            (row['friend_request_id'] ?? row['entity_id'] ?? row['edentity_id'])
                as String?,
        isRead: row['is_read'] as bool? ?? false,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
    }).toList();
  }

  @override
  Future<int> fetchUnreadCount() => _dataSource.fetchUnreadCount();

  @override
  Future<void> markAsRead(String notificationId) =>
      _dataSource.markAsRead(notificationId);

  @override
  Future<void> markAllAsRead() => _dataSource.markAllAsRead();

  @override
  Future<void Function()> subscribeToNew(
    void Function() onNewNotification,
  ) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return () {};
    final channel = _dataSource.subscribeToNewNotifications(
      userId,
      onNewNotification,
    );
    return () => _client.removeChannel(channel);
  }
}
