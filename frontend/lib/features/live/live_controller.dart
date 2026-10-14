import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/application/auth_controller.dart';
import '../auth/data/token_store.dart';
import '../market/domain/market.dart';
import '../notifications/data/notifications_api.dart';
import '../notifications/domain/app_notification.dart';
import '../profile/data/user_api.dart';
import 'live_connection.dart';

class LiveState {
  const LiveState({
    this.connected = false,
    this.quotes = const {},
    this.lastNotification,
  });

  final bool connected;

  /// Latest pushed prices by asset id; screens prefer these over the price they loaded.
  final Map<int, Quote> quotes;

  /// Most recent pushed notification (the app shows it as a pop-up).
  final AppNotification? lastNotification;

  LiveState copyWith({
    bool? connected,
    Map<int, Quote>? quotes,
    AppNotification? lastNotification,
  }) => LiveState(
    connected: connected ?? this.connected,
    quotes: quotes ?? this.quotes,
    lastNotification: lastNotification ?? this.lastNotification,
  );
}

/// Keeps one live connection open while signed in. Screens declare which assets they show
/// with [setInterest]; the union is subscribed on the server.
class LiveController extends Notifier<LiveState> {
  static const _unauthorized = 4401;

  final _interests = <String, Set<int>>{};
  LiveConnection? _connection;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  Timer? _retryTimer;
  int _attempt = 0;
  bool _wanted = false;

  @override
  LiveState build() {
    ref.listen(
      authControllerProvider.select((s) => s.isAuthenticated),
      (_, signedIn) => signedIn ? _start() : _stop(),
    );
    ref.onDispose(() {
      _wanted = false;
      _retryTimer?.cancel();
      _closeConnection();
    });
    // Start after build: the notifier's state must exist before connection events arrive.
    if (ref.read(authControllerProvider).isAuthenticated) {
      Future.microtask(_start);
    }
    return const LiveState();
  }

  void setInterest(String key, Iterable<int> assetIds) {
    _interests[key] = assetIds.toSet();
    _sendSubscription();
  }

  void clearInterest(String key) {
    if (_interests.remove(key) != null) _sendSubscription();
  }

  Set<int> get _subscribed => _interests.values.expand((ids) => ids).toSet();

  void _start() {
    _wanted = true;
    _attempt = 0;
    _connect();
  }

  void _stop() {
    _wanted = false;
    _retryTimer?.cancel();
    _closeConnection();
    state = const LiveState();
  }

  void _closeConnection() {
    _subscription?.cancel();
    _subscription = null;
    _connection?.close();
    _connection = null;
  }

  Future<void> _connect() async {
    _closeConnection();
    final token = ref.read(tokenStoreProvider).accessToken;
    if (!_wanted || token == null) return;
    final connection = ref.read(liveConnectionFactoryProvider)(liveUri());
    _connection = connection;
    try {
      await connection.ready;
    } catch (_) {
      if (identical(_connection, connection)) _scheduleReconnect();
      return;
    }
    if (!identical(_connection, connection)) return; // superseded
    _subscription = connection.messages.listen(
      _onMessage,
      onError: (_) => _onClosed(connection),
      onDone: () => _onClosed(connection),
    );
    connection.send({'type': 'auth', 'token': token});
  }

  void _onMessage(Map<String, dynamic> message) {
    switch (message['type']) {
      case 'ready':
        _attempt = 0;
        state = state.copyWith(connected: true);
        _sendSubscription();
      case 'quotes':
        final updates = (message['quotes'] as Map<String, dynamic>).map(
          (id, q) => MapEntry(
            int.parse(id),
            Quote.fromJson(q as Map<String, dynamic>),
          ),
        );
        state = state.copyWith(quotes: {...state.quotes, ...updates});
      case 'notification':
        final notification = AppNotification.fromJson(
          message['notification'] as Map<String, dynamic>,
        );
        ref
            .read(notificationsProvider.notifier)
            .received(notification, message['unread_count'] as int);
        state = state.copyWith(lastNotification: notification);
    }
  }

  Future<void> _onClosed(LiveConnection connection) async {
    if (!identical(_connection, connection) || !_wanted) return;
    state = state.copyWith(connected: false);
    if (connection.closeCode == _unauthorized) {
      // Access token expired: any authenticated call refreshes it (or signs the user out).
      try {
        await ref.read(userApiProvider).me();
      } catch (_) {
        return;
      }
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_wanted) return;
    _retryTimer?.cancel();
    final seconds = math.min(
      30,
      2 << math.min(_attempt, 4),
    ); // 2, 4, 8, 16, 30 s
    _attempt++;
    _retryTimer = Timer(Duration(seconds: seconds), _connect);
  }

  void _sendSubscription() {
    if (!state.connected) return;
    _connection?.send({'type': 'subscribe', 'asset_ids': _subscribed.toList()});
  }
}

final liveControllerProvider = NotifierProvider<LiveController, LiveState>(
  LiveController.new,
);

/// The freshest known quote for an asset: a live push if any, else what was loaded.
Quote? liveQuote(WidgetRef ref, Asset asset) =>
    ref.watch(liveControllerProvider.select((s) => s.quotes[asset.id])) ??
    asset.quote;
