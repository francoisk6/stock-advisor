import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/api_error.dart';
import '../../../core/router/app_shell.dart';
import '../../../core/format/numbers.dart';
import '../../../core/widgets/error_text.dart';
import '../../../core/widgets/snack.dart';
import '../../../l10n/app_localizations.dart';
import '../../learn/presentation/explain_sheet.dart';
import '../../market/presentation/widgets/asset_avatar.dart';
import '../../market/presentation/widgets/price_change.dart';
import '../data/practice_api.dart';
import '../domain/practice.dart';

/// The practice account: value, holdings, waiting orders and recent trades.
class PracticeScreen extends ConsumerWidget {
  const PracticeScreen({super.key});

  Future<void> _reset(
    BuildContext context,
    WidgetRef ref,
    PracticeAccount account,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final start = formatMoney(account.startingCash, 'USD');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.practiceResetTitle(start)),
        content: Text(l10n.practiceResetBody(start)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.practiceReset),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(practiceProvider.notifier).reset();
      showSnack(messenger, l10n.practiceResetDone(start));
    } catch (e) {
      showSnack(messenger, apiErrorMessage(e, l10n));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final account = ref.watch(practiceProvider);
    final history = ref.watch(practiceHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.practiceTitle),
        actions: [
          if (account.value case final a?)
            PopupMenuButton<String>(
              onSelected: (_) => _reset(context, ref, a),
              itemBuilder: (context) => [
                PopupMenuItem(value: 'reset', child: Text(l10n.practiceReset)),
              ],
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: RefreshIndicator(
            onRefresh: () async {
              refreshAll(ref.invalidate);
              await ref.read(practiceProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(l10n.practiceIntro, style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
                ...account.when(
                  loading: () => [
                    const Center(child: CircularProgressIndicator()),
                  ],
                  error: (e, _) => [ErrorText(apiErrorMessage(e, l10n))],
                  data: (a) => [
                    _Summary(account: a),
                    if (a.pending.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _SectionTitle(l10n.practiceWaiting),
                      for (final o in a.pending) _PendingTile(order: o),
                    ],
                    const SizedBox(height: 16),
                    _SectionTitle(
                      l10n.practiceHoldings,
                      onInfo: a.positions.isEmpty
                          ? null
                          : () => showExplainSheet(
                              context,
                              title: l10n.practiceHoldings,
                              help: l10n.practiceGainHelp,
                              termId: 'unrealized-gain',
                            ),
                    ),
                    if (a.positions.isEmpty) ...[
                      Text(l10n.practiceEmpty),
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FilledButton.tonalIcon(
                          icon: const Icon(Icons.search),
                          label: Text(l10n.practiceFindAsset),
                          onPressed: () => context.go('/search'),
                        ),
                      ),
                    ] else
                      for (final p in a.positions) _PositionTile(position: p),
                  ],
                ),
                ...switch (history.value) {
                  final orders? when orders.any((o) => o.status != 'pending') =>
                    [
                      const SizedBox(height: 16),
                      _SectionTitle(l10n.practiceHistory),
                      for (final o in orders.where(
                        (o) => o.status != 'pending',
                      ))
                        _HistoryTile(order: o),
                    ],
                  _ => const <Widget>[],
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.onInfo});

  final String text;
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Semantics(
            header: true,
            container: true,
            child: Text(text, style: theme.textTheme.titleMedium),
          ),
          if (onInfo != null)
            IconButton(
              tooltip: AppLocalizations.of(context).explainLearnMore,
              icon: Icon(
                Icons.info_outline,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              onPressed: onInfo,
            ),
        ],
      ),
    );
  }
}

/// Total value, gain since the start, and the cash / invested split — each explained.
class _Summary extends StatelessWidget {
  const _Summary({required this.account});

  final PracticeAccount account;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final a = account;

    Widget stat(String label, double value, String help, String? termId) =>
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => showExplainSheet(
              context,
              title: label,
              value: formatMoney(value, 'USD'),
              help: help,
              termId: termId,
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodySmall),
                  Text(
                    formatMoney(value, 'USD'),
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
        );

    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => showExplainSheet(
                context,
                title: l10n.practiceTotalValue,
                value: formatMoney(a.totalValue, 'USD'),
                help: l10n.practiceTotalValueHelp(
                  formatMoney(a.startingCash, 'USD'),
                ),
                termId: 'portfolio',
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.practiceTotalValue,
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    formatMoney(a.totalValue, 'USD'),
                    style: theme.textTheme.headlineMedium,
                  ),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      PriceChange(
                        percent: a.gainPercent,
                        amount: formatSignedMoney(a.gainUsd, 'USD'),
                      ),
                      Text(
                        l10n.practiceSince(
                          DateFormat.yMMMd().format(a.startedAt.toLocal()),
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                stat(
                  l10n.practiceCash,
                  a.availableCash,
                  l10n.practiceCashHelp,
                  null,
                ),
                stat(
                  l10n.practiceInvested,
                  a.positionsValue,
                  l10n.practiceInvestedHelp,
                  'position',
                ),
                if (a.realizedUsd != 0)
                  stat(
                    l10n.practiceRealized,
                    a.realizedUsd,
                    l10n.practiceRealizedHelp,
                    'realized-gain',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PositionTile extends StatelessWidget {
  const _PositionTile({required this.position});

  final PracticePosition position;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final p = position;
    final value = p.valueUsd;
    final share = p.sharePercent;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: AssetAvatar(asset: p.asset),
      title: Text(p.asset.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          l10n.practicePositionLine(
            '${formatQuantity(p.quantity)} ${p.asset.symbol}',
            formatPrice(p.averagePrice, p.currency),
          ),
          if (share != null)
            l10n.practiceShare(formatPercent(share, signed: false)),
        ].join('\n'),
      ),
      isThreeLine: share != null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            value == null ? '—' : formatMoney(value, 'USD'),
            style: theme.textTheme.titleSmall,
          ),
          PriceChange(
            percent: p.gainPercent,
            amount: p.gainUsd == null
                ? null
                : formatSignedMoney(p.gainUsd!, 'USD'),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
      onTap: () => context.go(assetLocation(context, p.asset.id)),
    );
  }
}

String orderText(AppLocalizations l10n, PracticeOrder o) {
  final symbol = o.asset.symbol;
  if (o.amountUsd != null) {
    final amount = formatMoney(o.amountUsd!, 'USD');
    return o.isBuy
        ? l10n.orderBuyAmount(amount, symbol)
        : l10n.orderSellAmount(amount, symbol);
  }
  final quantity = formatQuantity(o.quantity ?? 0);
  return o.isBuy
      ? l10n.orderBuyUnits(quantity, symbol)
      : l10n.orderSellUnits(quantity, symbol);
}

class _PendingTile extends ConsumerWidget {
  const _PendingTile({required this.order});

  final PracticeOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.schedule),
      title: Text(orderText(l10n, order)),
      subtitle: Text(
        DateFormat.MMMd().add_Hm().format(order.createdAt.toLocal()),
      ),
      trailing: TextButton(
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            await ref.read(practiceProvider.notifier).cancel(order.id);
            showSnack(messenger, l10n.practiceOrderCancelled);
          } catch (e) {
            showSnack(messenger, apiErrorMessage(e, l10n));
          }
        },
        child: Text(l10n.practiceCancelOrder),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.order});

  final PracticeOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final o = order;
    final when = DateFormat.MMMd().add_Hm().format(
      (o.filledAt ?? o.createdAt).toLocal(),
    );
    if (o.status != 'filled') {
      final status = switch (o.status) {
        'cancelled' => l10n.statusCancelled,
        'undone' => l10n.statusUndone,
        _ => l10n.statusRejected,
      };
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.block),
        title: Text('$status: ${orderText(l10n, o)}'),
        subtitle: Text([when, if (o.note != null) o.note!].join(' · ')),
      );
    }
    final quantity = formatQuantity(o.filledQuantity!);
    final gain = o.gainUsd;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        o.isBuy ? Icons.add_circle_outline : Icons.remove_circle_outline,
      ),
      title: Text(
        o.isBuy
            ? l10n.historyBought(quantity, o.asset.symbol)
            : l10n.historySold(quantity, o.asset.symbol),
      ),
      subtitle: Text(
        '${l10n.historyFill(formatPrice(o.price!, o.currency), formatMoney(o.totalUsd!, 'USD'))}'
        '\n$when',
      ),
      isThreeLine: true,
      trailing: gain == null
          ? null
          : Text(
              l10n.historyGain(formatSignedMoney(gain, 'USD')),
              style: theme.textTheme.bodySmall?.copyWith(
                color: changeColor(context, gain),
                fontWeight: FontWeight.w600,
              ),
            ),
      onTap: () => context.go(assetLocation(context, o.asset.id)),
    );
  }
}
