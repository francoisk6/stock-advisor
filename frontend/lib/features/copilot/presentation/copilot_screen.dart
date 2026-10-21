import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/numbers.dart';
import '../../../core/errors/api_error.dart';
import '../../../core/widgets/snack.dart';
import '../../../l10n/app_localizations.dart';
import '../../alerts/domain/alert.dart';
import '../../alerts/presentation/alert_text.dart';
import '../../auth/application/auth_controller.dart';
import '../../market/data/market_api.dart';
import '../application/copilot_controller.dart';
import '../data/chat_api.dart';
import 'rich_answer.dart';
import '../../plans/presentation/plan_limit.dart';

/// Chat with the copilot. Opened with `?asset=<id>` from an asset page to give it context.
class CopilotScreen extends ConsumerStatefulWidget {
  const CopilotScreen({super.key, this.assetId});

  final int? assetId;

  @override
  ConsumerState<CopilotScreen> createState() => _CopilotScreenState();
}

class _CopilotScreenState extends ConsumerState<CopilotScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(copilotControllerProvider.notifier).loadRemaining(),
    );
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final question = (text ?? _input.text).trim();
    if (question.isEmpty) return;
    ref
        .read(copilotControllerProvider.notifier)
        .send(question, assetId: widget.assetId);
    _input.clear();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(copilotControllerProvider);
    final controller = ref.read(copilotControllerProvider.notifier);
    ref.listen(
      copilotControllerProvider.select((s) => s.messages),
      (_, _) => _scrollToEnd(),
    );

    final contextSymbol = widget.assetId == null
        ? null
        : ref.watch(assetDetailProvider(widget.assetId!)).value?.asset.symbol;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          state.title ?? l10n.copilotTitle,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: l10n.copilotHistory,
            icon: const Icon(Icons.history),
            onPressed: () => _showHistory(context),
          ),
          IconButton(
            tooltip: l10n.copilotNewChat,
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: state.messages.isEmpty
                ? null
                : controller.newConversation,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                Expanded(
                  child: state.messages.isEmpty
                      ? _Welcome(symbol: contextSymbol, onAsk: _send)
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.all(16),
                          itemCount: state.messages.length,
                          itemBuilder: (context, i) => _Bubble(
                            message: state.messages[i],
                            onUndo: (actionIndex) async {
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await controller.undo(i, actionIndex);
                              } catch (e) {
                                showSnack(messenger, apiErrorMessage(e, l10n));
                              }
                            },
                          ),
                        ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          minLines: 1,
                          maxLines: 5,
                          maxLength: 2000,
                          textInputAction: TextInputAction.send,
                          onSubmitted: state.busy ? null : (_) => _send(),
                          decoration: InputDecoration(
                            hintText: l10n.copilotHint,
                            counterText: '',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      state.busy
                          ? IconButton.filledTonal(
                              tooltip: l10n.copilotStop,
                              icon: const Icon(Icons.stop),
                              onPressed: controller.stop,
                            )
                          : IconButton.filled(
                              tooltip: l10n.copilotSend,
                              icon: const Icon(Icons.send),
                              onPressed: _send,
                            ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    [
                      if (state.remainingToday case final left?)
                        l10n.copilotRemaining(left),
                      l10n.copilotDisclaimer,
                    ].join(' · '),
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showHistory(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      useRootNavigator: true, // above the tab bar
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) {
          final conversations = ref.watch(conversationsProvider);
          return SafeArea(
            child: conversations.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text(apiErrorMessage(e, l10n)),
              ),
              data: (items) => items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(l10n.copilotHistoryEmpty),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final c in items)
                          ListTile(
                            leading: const Icon(Icons.chat_bubble_outline),
                            title: Text(
                              c.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              ref
                                  .read(copilotControllerProvider.notifier)
                                  .open(c.id);
                            },
                            trailing: IconButton(
                              tooltip: l10n.copilotDeleteChat,
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                await ref.read(chatApiProvider).delete(c.id);
                                if (ref
                                        .read(copilotControllerProvider)
                                        .conversationId ==
                                    c.id) {
                                  ref
                                      .read(copilotControllerProvider.notifier)
                                      .newConversation();
                                }
                                ref.invalidate(conversationsProvider);
                              },
                            ),
                          ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _Welcome extends ConsumerWidget {
  const _Welcome({required this.symbol, required this.onAsk});

  final String? symbol;
  final void Function(String) onAsk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final name = ref.watch(authControllerProvider).user?.displayName ?? '';
    final s = symbol;
    final starters = s == null
        ? [
            l10n.copilotStarterBitcoin,
            l10n.copilotStarterPe,
            l10n.copilotStarterWatchlist,
            l10n.copilotStarterAdd,
          ]
        : [
            l10n.copilotStarterAssetMonth(s),
            l10n.copilotStarterAssetFigures(s),
            l10n.copilotStarterAssetRisks(s),
            l10n.copilotStarterAssetAlert(s),
          ];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(Icons.auto_awesome, size: 40, color: theme.colorScheme.primary),
        const SizedBox(height: 12),
        Text(l10n.copilotWelcome(name), style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        Text(l10n.copilotTryAsking, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        for (final question in starters)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                alignment: AlignmentDirectional.centerStart,
                padding: const EdgeInsets.all(14),
              ),
              onPressed: () => onAsk(question),
              child: Text(question),
            ),
          ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.onUndo});

  final CopilotMessage message;
  final void Function(int actionIndex) onUndo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final user = message.fromUser;
    final error = message.error;

    return Align(
      alignment: user
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: user ? colors.primaryContainer : colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (user)
                Text(message.text, style: theme.textTheme.bodyLarge)
              else if (message.text.isNotEmpty)
                RichAnswer(message.text),
              if (message.status case final status?) ...[
                if (message.text.isNotEmpty) const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(status, style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
              ] else if (message.streaming && message.text.isEmpty)
                const SizedBox(width: 24, child: LinearProgressIndicator()),
              for (final (i, card) in message.actions.indexed)
                _ActionCard(card: card, onUndo: () => onUndo(i)),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        error == 'offline' ? l10n.copilotOffline : error,
                        style: TextStyle(color: colors.error),
                      ),
                      if (message.errorCode == 'plan_limit')
                        const SeePlansButton(),
                    ],
                  ),
                )
              else if (!user && !message.streaming && message.text.isEmpty)
                Text(l10n.copilotStopped, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.card, required this.onUndo});

  final Map<String, dynamic> card;
  final VoidCallback onUndo;

  String _practiceText(AppLocalizations l10n) {
    final symbol = card['symbol'] as String;
    final quantity = formatQuantity((card['quantity'] as num? ?? 0).toDouble());
    final total = formatMoney(
      (card['total_usd'] as num? ?? 0).toDouble(),
      'USD',
    );
    return switch (card['status']) {
      'filled' when card['side'] == 'sell' => l10n.actionPracticeSold(
        quantity,
        symbol,
        total,
      ),
      'filled' => l10n.actionPracticeBought(quantity, symbol, total),
      'pending' => l10n.actionPracticeWaiting(symbol),
      _ => l10n.actionPracticeRejected(symbol),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = (card['name'] ?? card['symbol'] ?? '') as String;
    final (icon, text) = switch (card['type']) {
      'watchlist_added' => (Icons.star, l10n.actionWatchlistAdded(name)),
      'watchlist_removed' => (
        Icons.star_border,
        l10n.actionWatchlistRemoved(name),
      ),
      'alert_created' => (
        Icons.notifications_active_outlined,
        l10n.actionAlertCreated(
          card['symbol'] as String,
          alertDescription(
            l10n,
            AlertKindJson.parse(card['kind'] as String),
            (card['threshold'] as num).toDouble(),
            card['currency'] as String?,
          ),
        ),
      ),
      'practice_order' => (Icons.sports_esports_outlined, _practiceText(l10n)),
      'lesson' => (Icons.school_outlined, l10n.actionLesson(name)),
      'glossary_term' => (
        Icons.menu_book_outlined,
        l10n.actionGlossaryTerm(name),
      ),
      _ => (Icons.check, card['type'].toString()),
    };
    // Practice orders that weren't carried out have nothing to undo.
    final undoable =
        card['type'] != 'practice_order' ||
        const {'filled', 'pending'}.contains(card['status']);
    if (!undoable) {
      return Card(
        margin: const EdgeInsets.only(top: 8),
        child: ListTile(
          dense: true,
          leading: Icon(icon),
          title: Text(text),
          subtitle: card['note'] == null ? null : Text(card['note'] as String),
          onTap: () => context.go('/practice'),
        ),
      );
    }
    if (card['type'] == 'glossary_term' || card['type'] == 'lesson') {
      return Card(
        margin: const EdgeInsets.only(top: 8),
        child: ListTile(
          dense: true,
          leading: Icon(icon),
          title: Text(text),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go(
            card['type'] == 'lesson'
                ? '/learn/lessons/${card['lesson_id']}'
                : '/learn/${card['term_id']}',
          ),
        ),
      );
    }
    final undone = card['undone'] == true;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        dense: true,
        leading: Icon(icon),
        title: Text(
          text,
          style: undone
              ? const TextStyle(decoration: TextDecoration.lineThrough)
              : null,
        ),
        onTap: () => context.go(
          card['type'] == 'practice_order'
              ? '/practice'
              : '/assets/${card['asset_id']}',
        ),
        trailing: undone
            ? Text(l10n.actionUndone)
            : TextButton(onPressed: onUndo, child: Text(l10n.actionUndo)),
      ),
    );
  }
}
