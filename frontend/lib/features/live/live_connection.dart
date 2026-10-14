import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/config/app_config.dart';

/// Thin wrapper over a WebSocket so the live controller can be tested with a fake.
abstract class LiveConnection {
  Future<void> get ready;
  Stream<Map<String, dynamic>> get messages;
  int? get closeCode;
  void send(Map<String, dynamic> message);
  Future<void> close();
}

class _WebSocketLiveConnection implements LiveConnection {
  _WebSocketLiveConnection(Uri uri) : _channel = WebSocketChannel.connect(uri);

  final WebSocketChannel _channel;

  @override
  Future<void> get ready => _channel.ready;

  @override
  Stream<Map<String, dynamic>> get messages => _channel.stream
      .map((raw) => jsonDecode(raw as String))
      .where((m) => m is Map<String, dynamic>)
      .cast<Map<String, dynamic>>();

  @override
  int? get closeCode => _channel.closeCode;

  @override
  void send(Map<String, dynamic> message) =>
      _channel.sink.add(jsonEncode(message));

  @override
  Future<void> close() async => _channel.sink.close();
}

/// `ws(s)://{api host}/api/v1/ws`, derived from the REST base URL.
Uri liveUri() {
  final api = Uri.parse(AppConfig.apiBaseUrl);
  return api.replace(
    scheme: api.scheme == 'https' ? 'wss' : 'ws',
    path: '${api.path}/ws',
  );
}

typedef LiveConnectionFactory = LiveConnection Function(Uri uri);

final liveConnectionFactoryProvider = Provider<LiveConnectionFactory>(
  (ref) => _WebSocketLiveConnection.new,
);
