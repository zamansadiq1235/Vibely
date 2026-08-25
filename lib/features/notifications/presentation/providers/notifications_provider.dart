import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/supabase_client_provider.dart';
import '../../data/datasources/notifications_remote_data_source.dart';
import '../../data/repositories/notifications_repository_impl.dart';
import '../../domain/entities/notification_item.dart';
import '../../domain/repositories/notifications_repository.dart';

// ---------- Dependency injection ----------

final notificationsRemoteDataSourceProvider =
    Provider<NotificationsRemoteDataSource>((ref) {
      return NotificationsRemoteDataSource(ref.watch(supabaseClientProvider));
    });

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  return NotificationsRepositoryImpl(
    ref.watch(notificationsRemoteDataSourceProvider),
    ref.watch(supabaseClientProvider),
  );
});

// ---------- State ----------

class NotificationsState {
  const NotificationsState({
    required this.items,
    required this.hasMore,
    required this.unreadCount,
  });

  final List<NotificationItem> items;
  final bool hasMore;
  final int unreadCount;

  NotificationsState copyWith({
    List<NotificationItem>? items,
    bool? hasMore,
    int? unreadCount,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

/// Fetches page 0 + the unread count on build, subscribes to Realtime
/// inserts for the lifetime of the provider, and unsubscribes via
/// `ref.onDispose` — so leaving the Notifications screen or closing the
/// app cleans the channel up rather than leaking a Realtime subscription
/// per visit.
class NotificationsNotifier extends AsyncNotifier<NotificationsState> {
  int _page = 0;
  bool _isFetchingMore = false;
  void Function()? _unsubscribe;

  @override
  Future<NotificationsState> build() async {
    _page = 0;
    final repo = ref.read(notificationsRepositoryProvider);

    final results = await Future.wait([
      repo.fetchNotifications(page: 0),
      repo.fetchUnreadCount(),
    ]);
    final items = results[0] as List<NotificationItem>;
    final unreadCount = results[1] as int;

    final unsubscribe = await repo.subscribeToNew(_onRealtimeInsert);
    _unsubscribe = unsubscribe;
    ref.onDispose(() => _unsubscribe?.call());

    return NotificationsState(
      items: items,
      hasMore: items.length == AppConstants.notificationsPageSize,
      unreadCount: unreadCount,
    );
  }

  /// A new notification arrived over Realtime. The row itself isn't
  /// passed through (see the data source's doc comment), so this just
  /// re-fetches page 0 and merges anything not already shown — cheap
  /// enough for a "someone just liked your video" cadence, and far
  /// simpler than reassembling a partial entity from a bare payload.
  Future<void> _onRealtimeInsert() async {
    final current = state.asData?.value;
    if (current == null) return;
    try {
      final repo = ref.read(notificationsRepositoryProvider);
      final results = await Future.wait([
        repo.fetchNotifications(page: 0),
        repo.fetchUnreadCount(),
      ]);
      final latest = results[0] as List<NotificationItem>;
      final unreadCount = results[1] as int;

      final existingIds = current.items.map((n) => n.id).toSet();
      final newOnes = latest.where((n) => !existingIds.contains(n.id)).toList();
      if (newOnes.isEmpty && unreadCount == current.unreadCount) return;

      state = AsyncData(
        current.copyWith(
          items: [...newOnes, ...current.items],
          unreadCount: unreadCount,
        ),
      );
    } catch (_) {
      // Realtime is a convenience; a failed refresh here just means the
      // badge updates next time the user opens the tab instead.
    }
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore || _isFetchingMore) return;
    _isFetchingMore = true;
    final nextPage = _page + 1;
    try {
      final more = await ref
          .read(notificationsRepositoryProvider)
          .fetchNotifications(page: nextPage);
      _page = nextPage;
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...more],
          hasMore: more.length == AppConstants.notificationsPageSize,
        ),
      );
    } catch (_) {
    } finally {
      _isFetchingMore = false;
    }
  }

  Future<void> markAsRead(String notificationId) async {
    final current = state.asData?.value;
    if (current == null) return;

    NotificationItem? target;
    for (final n in current.items) {
      if (n.id == notificationId) {
        target = n;
        break;
      }
    }
    if (target == null || target.isRead) return;

    state = AsyncData(
      current.copyWith(
        items: [
          for (final n in current.items)
            n.id == notificationId ? n.copyWith(isRead: true) : n,
        ],
        unreadCount: current.unreadCount > 0 ? current.unreadCount - 1 : 0,
      ),
    );
    try {
      await ref
          .read(notificationsRepositoryProvider)
          .markAsRead(notificationId);
    } catch (_) {
      // Leave the optimistic read-state as-is; worst case the item is
      // shown read locally but the server still has it unread until the
      // next fetch reconciles it. Not worth a rollback + user-facing
      // error for something this low-stakes.
    }
  }

  Future<void> markAllAsRead() async {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        items: [for (final n in current.items) n.copyWith(isRead: true)],
        unreadCount: 0,
      ),
    );
    try {
      await ref.read(notificationsRepositoryProvider).markAllAsRead();
    } catch (_) {}
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, NotificationsState>(
      NotificationsNotifier.new,
    );

/// Convenience for the bottom-nav badge — reads the same state without
/// every consumer needing to unwrap AsyncValue itself.
final unreadNotificationsCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).asData?.value.unreadCount ?? 0;
});
