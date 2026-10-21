import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../alerts/data/alerts_api.dart';
import '../../practice/data/practice_api.dart';
import '../../live/live_controller.dart';
import '../../watchlist/data/watchlist_api.dart';
import '../data/chat_api.dart';

class CopilotMessage {
  const CopilotMessage({
    required this.fromUser,
    this.text = '',
    this.actions = const [],
    this.status,
    this.streaming = false,
    this.error,
  });

  final bool fromUser;
  final String text;

  /// Cards for things the copilot did (`type`: watchlist_added, watchlist_removed,
  /// alert_created); `undone: true` once the user undid it.
  final List<Map<String, dynamic>> actions;

  /// What the copilot is doing right now ("Looking up the price of BTC…").
  final String? status;
  final bool streaming;

  /// Error detail from the server, or the code `offline`.
  final String? error;

  CopilotMessage copyWith({
    String? text,
    List<Map<String, dynamic>>? actions,
    String? status,
    bool clearStatus = false,
    bool? streaming,
    String? error,
  }) => CopilotMessage(
    fromUser: fromUser,
    text: text ?? this.text,
    actions: actions ?? this.actions,
    status: clearStatus ? null : status ?? this.status,
    streaming: streaming ?? this.streaming,
    error: error ?? this.error,
  );
}

class CopilotState {
  const CopilotState({
    this.conversationId,
    this.title,
    this.messages = const [],
    this.remainingToday,
  });

  final int? conversationId;
  final String? title;
  final List<CopilotMessage> messages;
  final int? remainingToday;

  bool get busy => messages.isNotEmpty && messages.last.streaming;

  CopilotState copyWith({
    int? conversationId,
    String? title,
    List<CopilotMessage>? messages,
    int? remainingToday,
  }) => CopilotState(
    conversationId: conversationId ?? this.conversationId,
    title: title ?? this.title,
    messages: messages ?? this.messages,
    remainingToday: remainingToday ?? this.remainingToday,
  );
}

/// The open copilot conversation. Kept while navigating, so an answer keeps streaming.
class CopilotController extends Notifier<CopilotState> {
  StreamSubscription<Map<String, dynamic>>? _subscription;
  String? _requestId;

  @override
  CopilotState build() {
    ref.onDispose(() => _subscription?.cancel());
    return const CopilotState();
  }

  void _updateLast(CopilotMessage Function(CopilotMessage) change) {
    final messages = [...state.messages];
    messages[messages.length - 1] = change(messages.last);
    state = state.copyWith(messages: messages);
  }

  void send(String text, {int? assetId}) {
    final question = text.trim();
    if (question.isEmpty || state.busy) return;
    state = state.copyWith(
      messages: [
        ...state.messages,
        CopilotMessage(fromUser: true, text: question),
        const CopilotMessage(fromUser: false, streaming: true),
      ],
    );
    final (id, events) = ref.read(liveControllerProvider.notifier).sendChat({
      'text': question,
      'conversation_id': state.conversationId,
      'asset_id': assetId,
    });
    _requestId = id;
    _subscription = events.listen(_onEvent, onDone: _finishIfStreaming);
  }

  void _onEvent(Map<String, dynamic> event) {
    switch (event['event']) {
      case 'conversation':
        state = state.copyWith(
          conversationId: event['conversation_id'] as int,
          title: event['title'] as String,
        );
      case 'status':
        _updateLast((m) => m.copyWith(status: event['text'] as String));
      case 'retract':
        // The server is redoing the answer (e.g. it must look the news up first).
        _updateLast((m) => m.copyWith(text: ''));
      case 'delta':
        _updateLast(
          (m) => m.copyWith(text: m.text + (event['text'] as String)),
        );
      case 'action':
        final card = Map<String, dynamic>.from(event['card'] as Map);
        _updateLast((m) => m.copyWith(actions: [...m.actions, card]));
        _refreshAffected(card);
      case 'done':
        _updateLast(
          (m) => m.copyWith(
            text: event['text'] as String,
            streaming: false,
            clearStatus: true,
          ),
        );
        state = state.copyWith(
          remainingToday: event['remaining_today'] as int?,
        );
      case 'error':
        _updateLast(
          (m) => m.copyWith(
            streaming: false,
            clearStatus: true,
            error: (event['detail'] ?? event['code'] ?? 'error') as String,
          ),
        );
    }
  }

  void _finishIfStreaming() {
    if (state.busy) {
      _updateLast((m) => m.copyWith(streaming: false, clearStatus: true));
    }
  }

  /// Stops waiting for the current answer (the server stops working on it too).
  void stop() {
    final id = _requestId;
    if (id != null) ref.read(liveControllerProvider.notifier).cancelChat(id);
    _subscription?.cancel();
    _finishIfStreaming();
  }

  void newConversation() {
    stop();
    state = CopilotState(remainingToday: state.remainingToday);
  }

  Future<void> open(int conversationId) async {
    stop();
    final (title, stored) = await ref
        .read(chatApiProvider)
        .conversation(conversationId);
    state = CopilotState(
      conversationId: conversationId,
      title: title,
      remainingToday: state.remainingToday,
      messages: [
        for (final m in stored)
          CopilotMessage(
            fromUser: m.role == 'user',
            text: m.content,
            actions: m.actions,
          ),
      ],
    );
  }

  Future<void> loadRemaining() async {
    try {
      final remaining = await ref.read(chatApiProvider).remainingToday();
      state = state.copyWith(remainingToday: remaining);
    } catch (_) {
      // Only informational.
    }
  }

  /// Reverses an action card (removes the watchlist item / deletes the alert).
  Future<void> undo(int messageIndex, int actionIndex) async {
    final card = state.messages[messageIndex].actions[actionIndex];
    switch (card['type']) {
      case 'watchlist_added':
        await ref
            .read(watchlistProvider.notifier)
            .remove(card['asset_id'] as int);
      case 'watchlist_removed':
        await ref.read(watchlistProvider.notifier).add(card['asset_id'] as int);
      case 'alert_created':
        await ref.read(alertsApiProvider).delete(card['alert_id'] as int);
        ref.invalidate(alertsProvider(null));
        ref.invalidate(alertsProvider(card['asset_id'] as int));
      case 'practice_order':
        await ref.read(practiceApiProvider).undo(card['order_id'] as int);
        refreshAll(ref.invalidate);
    }
    final messages = [...state.messages];
    final actions = [...messages[messageIndex].actions];
    actions[actionIndex] = {...card, 'undone': true};
    messages[messageIndex] = messages[messageIndex].copyWith(actions: actions);
    state = state.copyWith(messages: messages);
  }

  void _refreshAffected(Map<String, dynamic> card) {
    if ((card['type'] as String).startsWith('watchlist')) {
      ref.invalidate(watchlistProvider);
    } else if (card['type'] == 'alert_created') {
      ref.invalidate(alertsProvider(null));
      ref.invalidate(alertsProvider(card['asset_id'] as int));
    } else if (card['type'] == 'practice_order') {
      refreshAll(ref.invalidate);
    }
  }
}

final copilotControllerProvider =
    NotifierProvider<CopilotController, CopilotState>(CopilotController.new);
