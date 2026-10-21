import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_error.dart';
import '../../../core/format/numbers.dart';
import '../../../core/widgets/error_text.dart';
import '../../../core/widgets/snack.dart';
import '../../../l10n/app_localizations.dart';
import '../../learn/presentation/explain_sheet.dart';
import '../../market/presentation/labels.dart';
import '../../market/presentation/widgets/asset_avatar.dart';
import '../../market/presentation/widgets/price_change.dart';
import '../../onboarding/presentation/profile_options.dart';
import '../data/portfolio_api.dart';
import '../domain/portfolio.dart';
import 'holding_sheet.dart';

/// Currencies offered for showing values (the user's current one is always included).
const displayCurrencies = [
  'USD',
  'EUR',
  'GBP',
  'SAR',
  'AED',
  'QAR',
  'KWD',
  'EGP',
  'JPY',
  'INR',
  'CHF',
  'CAD',
  'AUD',
];

String regionLabel(AppLocalizations l, String key) =>
    regionOptions(l).where((o) => o.code == key).firstOrNull?.title ?? key;

/// Plain sentence + glossary entry for a risk note.
(String, String) riskText(AppLocalizations l, RiskNote r) {
  String pct(String key) =>
      formatPercent((r.params[key] as num).toDouble(), signed: false);
  return switch (r.code) {
    'concentration' => (
      l.riskConcentration(
        r.params['symbol'] as String,
        pct('percent'),
        pct('drop_if_30'),
      ),
      'diversification',
    ),
    'crypto_share' => (l.riskCrypto(pct('percent')), 'volatility'),
    'foreign_currency' => (
      l.riskForeign(pct('percent'), r.params['currency'] as String),
      'exchange-rate',
    ),
    'few_holdings' => (
      l.riskFew((r.params['count'] as num).toInt()),
      'diversification',
    ),
    'one_region' => (
      l.riskOneRegion(regionLabel(l, r.params['region'] as String)),
      'diversification',
    ),
    _ => (
      l.riskSpread('${r.params['count']}', pct('top_percent')),
      'diversification',
    ),
  };
}

Future<void> addHolding(BuildContext context) async {
  final asset = await AssetPickerSheet.pick(context);
  if (asset != null && context.mounted) {
    await HoldingSheet.show(context, asset);
  }
}

class PortfolioScreen extends ConsumerWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final portfolio = ref.watch(portfolioProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.portfolioTitle)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l10n.portfolioAdd),
        onPressed: () => addHolding(context),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(portfolioProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Text(l10n.portfolioPrivacy, style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
                ...portfolio.when(
                  loading: () => [
                    const Center(child: CircularProgressIndicator()),
                  ],
                  error: (e, _) => [ErrorText(apiErrorMessage(e, l10n))],
                  data: (p) => p.holdings.isEmpty
                      ? [Text(l10n.portfolioEmpty)]
                      : [
                          _Summary(portfolio: p),
                          const SizedBox(height: 16),
                          _Risks(portfolio: p),
                          const SizedBox(height: 16),
                          _Allocation(portfolio: p),
                          const SizedBox(height: 16),
                          _Header(l10n.practiceHoldings),
                          for (final h in p.holdings)
                            _HoldingTile(holding: h, currency: p.currency),
                        ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Semantics(
      header: true,
      container: true,
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}

class _Summary extends ConsumerWidget {
  const _Summary({required this.portfolio});

  final Portfolio portfolio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final p = portfolio;
    final currencies = {...displayCurrencies, p.currency}.toList();

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
                value: formatMoney(p.totalValue, p.currency),
                help: l10n.portfolioTotalHelp(p.currency),
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
                    formatMoney(p.totalValue, p.currency),
                    style: theme.textTheme.headlineMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Tooltip(
                  message: l10n.portfolioGain,
                  excludeFromSemantics: true,
                  child: Semantics(
                    button: true,
                    label: l10n.portfolioGain,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => showExplainSheet(
                        context,
                        title: l10n.portfolioGain,
                        value: formatSignedMoney(p.gain, p.currency),
                        help: l10n.portfolioGainHelp,
                        termId: 'unrealized-gain',
                      ),
                      child: PriceChange(
                        percent: p.gainPercent,
                        amount: formatSignedMoney(p.gain, p.currency),
                      ),
                    ),
                  ),
                ),
                Text(
                  l10n.portfolioToday(
                    formatSignedMoney(p.dayChange, p.currency),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: changeColor(context, p.dayChange),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(l10n.portfolioShowIn, style: theme.textTheme.bodySmall),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: p.currency,
                  items: [
                    for (final c in currencies)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (c) async {
                    if (c == null || c == p.currency) return;
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await ref.read(portfolioProvider.notifier).setCurrency(c);
                    } catch (e) {
                      showSnack(messenger, apiErrorMessage(e, l10n));
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Risks extends StatelessWidget {
  const _Risks({required this.portfolio});

  final Portfolio portfolio;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(l10n.portfolioRisk),
        for (final r in portfolio.risks)
          Builder(
            builder: (context) {
              final (text, term) = riskText(l10n, r);
              final good = r.level == 'good';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  good
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_rounded,
                  color: good
                      ? changeColor(context, 1)
                      : theme.colorScheme.tertiary,
                ),
                title: Text(text),
                trailing: IconButton(
                  tooltip: l10n.explainLearnMore,
                  icon: const Icon(Icons.menu_book_outlined),
                  onPressed: () => showExplainSheet(
                    context,
                    title: l10n.portfolioRisk,
                    help: text,
                    termId: term,
                  ),
                ),
              );
            },
          ),
        Text(l10n.riskNote, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// Horizontal bars: readable, accessible (each row is text) and fine on small screens.
class _Allocation extends StatefulWidget {
  const _Allocation({required this.portfolio});

  final Portfolio portfolio;

  @override
  State<_Allocation> createState() => _AllocationState();
}

class _AllocationState extends State<_Allocation> {
  String _by = 'type';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final p = widget.portfolio;
    final (slices, label) = switch (_by) {
      'region' => (p.byRegion, (String k) => regionLabel(l10n, k)),
      'currency' => (p.byCurrency, (String k) => k),
      _ => (p.byType, (String k) => assetTypeLabel(l10n, k)),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(l10n.portfolioAllocation),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'type', label: Text(l10n.allocationType)),
            ButtonSegment(value: 'region', label: Text(l10n.allocationRegion)),
            ButtonSegment(
              value: 'currency',
              label: Text(l10n.allocationCurrency),
            ),
          ],
          selected: {_by},
          onSelectionChanged: (s) => setState(() => _by = s.first),
        ),
        const SizedBox(height: 8),
        for (final s in slices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(label(s.key))),
                    Text(
                      '${formatPercent(s.percent, signed: false)} · '
                      '${formatMoney(s.value, p.currency)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ExcludeSemantics(
                  child: LinearProgressIndicator(
                    value: s.percent / 100,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _HoldingTile extends StatelessWidget {
  const _HoldingTile({required this.holding, required this.currency});

  final Holding holding;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final h = holding;
    final share = h.sharePercent;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: AssetAvatar(asset: h.asset),
      title: Text(h.asset.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          l10n.holdingLine(
            '${formatQuantity(h.quantity)} ${h.asset.symbol}',
            formatPrice(h.averagePrice, h.currency),
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
            h.value == null ? '—' : formatMoney(h.value!, currency),
            style: theme.textTheme.titleSmall,
          ),
          PriceChange(
            percent: h.gainPercent,
            amount: h.gain == null
                ? null
                : formatSignedMoney(h.gain!, currency),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
      onTap: () => HoldingSheet.show(context, h.asset, holding: h),
    );
  }
}
