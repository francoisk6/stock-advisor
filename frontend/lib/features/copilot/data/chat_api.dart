import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.title,
    required this.updatedAt,
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> json) =>
      ConversationSummary(
        id: json['id'] as int,
        title: json['title'] as String,
        updatedAt: DateTime.parse('${json['updated_at']}Z'),
      );

  final int id;
  final String title;
  final DateTime updatedAt;
}

class StoredChatMessage {
  const StoredChatMessage({
    required this.role,
    required this.content,
    required this.actions,
  });

  factory StoredChatMessage.fromJson(Map<String, dynamic> json) =>
      StoredChatMessage(
        role: json['role'] as String,
        content: json['content'] as String,
        actions: [
          for (final a in json['actions'] as List)
            Map<String, dynamic>.from(a as Map),
        ],
      );

  final String role;
  final String content;
  final List<Map<String, dynamic>> actions;
}

class ChatApi {
  const ChatApi(this._dio);

  final Dio _dio;

  Future<List<ConversationSummary>> conversations() async {
    final response = await _dio.get<List<dynamic>>('/chat/conversations');
    return [
      for (final c in response.data!)
        ConversationSummary.fromJson(c as Map<String, dynamic>),
    ];
  }

  Future<(String, List<StoredChatMessage>)> conversation(int id) async {
    final data = (await _dio.get<Map<String, dynamic>>(
      '/chat/conversations/$id',
    )).data!;
    return (
      data['title'] as String,
      [
        for (final m in data['messages'] as List)
          StoredChatMessage.fromJson(m as Map<String, dynamic>),
      ],
    );
  }

  Future<void> delete(int id) => _dio.delete<void>('/chat/conversations/$id');

  /// Questions left today (null = unlimited).
  Future<int?> remainingToday() async {
    final data = (await _dio.get<Map<String, dynamic>>('/chat/usage')).data!;
    final limit = data['limit'] as int?;
    return limit == null
        ? null
        : (limit - (data['used_today'] as int)).clamp(0, limit);
  }
}

final chatApiProvider = Provider<ChatApi>(
  (ref) => ChatApi(ref.watch(dioProvider)),
);

final conversationsProvider =
    FutureProvider.autoDispose<List<ConversationSummary>>(
      (ref) => ref.watch(chatApiProvider).conversations(),
    );
