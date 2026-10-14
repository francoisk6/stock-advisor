import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/app_notification.dart';

class NotificationsApi {
  const NotificationsApi(this._dio);

  final Dio _dio;

  Future<NotificationInbox> list() async => NotificationInbox.fromJson(
    (await _dio.get<Map<String, dynamic>>('/notifications')).data!,
  );

  Future<void> markRead(int id) => _dio.post<void>('/notifications/$id/read');

  Future<void> markAllRead() => _dio.post<void>('/notifications/read-all');
}

final notificationsApiProvider = Provider<NotificationsApi>(
  (ref) => NotificationsApi(ref.watch(dioProvider)),
);

/// Inbox + unread badge. Live pushes are merged in via [NotificationsController.received].
class NotificationsController extends AsyncNotifier<NotificationInbox> {
  @override
  Future<NotificationInbox> build() =>
      ref.watch(notificationsApiProvider).list();

  void received(AppNotification notification, int unreadCount) {
    final items = state.value?.items ?? const <AppNotification>[];
    state = AsyncData(
      NotificationInbox(
        unreadCount: unreadCount,
        items: [notification, ...items.where((n) => n.id != notification.id)],
      ),
    );
  }

  Future<void> markRead(int id) async {
    final inbox = state.value;
    if (inbox == null) return;
    final target = inbox.items.where((n) => n.id == id).firstOrNull;
    if (target == null || target.read) return;
    state = AsyncData(
      NotificationInbox(
        unreadCount: (inbox.unreadCount - 1).clamp(0, 1 << 30),
        items: [for (final n in inbox.items) n.id == id ? n.markRead() : n],
      ),
    );
    await ref.read(notificationsApiProvider).markRead(id);
  }

  Future<void> markAllRead() async {
    final inbox = state.value;
    if (inbox == null) return;
    state = AsyncData(
      NotificationInbox(
        unreadCount: 0,
        items: [for (final n in inbox.items) n.markRead()],
      ),
    );
    await ref.read(notificationsApiProvider).markAllRead();
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsController, NotificationInbox>(
      NotificationsController.new,
    );
