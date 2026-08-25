import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';

class NotificationsRemoteDataSource {
  NotificationsRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> fetchNotificationRows({
    required int page,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw AppException.unauthorized();
    final from = page * AppConstants.notificationsPageSize;
    final to = from + AppConstants.notificationsPageSize - 1;
    try {
      final rows = await _client
          .from('notifications')
          .select(
            '*, actor:profiles!notifications_actor_id_fkey(username, avatar_path)',
          )
          .eq('recipient_id', userId)
          .order('created_at', ascending: false)
          .range(from, to);
      return List<Map<String, dynamic>>.from(rows as List);
    } on PostgrestException {
      throw AppException.unknown('Could not load notifications.');
    } catch (_) {
      throw AppException.network();
    }
  }

  Future<int> fetchUnreadCount() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;
    try {
      final response = await _client
          .from('notifications')
          .select('id')
          .eq('recipient_id', userId)
          .eq('is_read', false)
          .count(CountOption.exact);
      return response.count;
    } catch (_) {
      return 0;
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (_) {
      throw AppException.unknown('Could not update this notification.');
    }
  }

  Future<void> markAllAsRead() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw AppException.unauthorized();
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('recipient_id', userId)
          .eq('is_read', false);
    } catch (_) {
      throw AppException.unknown('Could not mark all as read.');
    }
  }

  /// One Realtime channel per call, filtered server-side to just this
  /// user's own notifications — every insert (any of the 8 trigger
  /// functions from migration 0004) fires [onInsert]. The caller only
  /// gets a signal, not the row itself, since the row alone lacks the
  /// joined actor profile the UI needs; the notifier re-fetches page 0
  /// on that signal instead of hand-assembling a partial entity here.
  RealtimeChannel subscribeToNewNotifications(
    String userId,
    void Function() onInsert,
  ) {
    final channel = _client.channel('notifications:$userId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: userId,
          ),
          callback: (payload) => onInsert(),
        )
        .subscribe();
    return channel;
  }

  String? resolveAvatarUrl(String? path) => path == null
      ? null
      : _client.storage.from(AppConstants.avatarsBucket).getPublicUrl(path);
}
