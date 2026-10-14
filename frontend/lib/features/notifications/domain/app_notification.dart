class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.assetId,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as int,
        kind: json['kind'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        assetId: json['asset_id'] as int?,
        read: json['read'] as bool,
        createdAt: DateTime.parse('${json['created_at']}Z'),
      );

  final int id;
  final String kind;
  final String title;
  final String body;
  final int? assetId;
  final bool read;
  final DateTime createdAt;

  AppNotification markRead() => AppNotification(
    id: id,
    kind: kind,
    title: title,
    body: body,
    assetId: assetId,
    read: true,
    createdAt: createdAt,
  );
}

class NotificationInbox {
  const NotificationInbox({required this.unreadCount, required this.items});

  factory NotificationInbox.fromJson(Map<String, dynamic> json) =>
      NotificationInbox(
        unreadCount: json['unread_count'] as int,
        items: [
          for (final n in json['items'] as List)
            AppNotification.fromJson(n as Map<String, dynamic>),
        ],
      );

  final int unreadCount;
  final List<AppNotification> items;
}
