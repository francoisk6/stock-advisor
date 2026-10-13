import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/api_error.dart';
import '../../../core/format/numbers.dart';
import '../../../core/widgets/error_text.dart';
import '../../../l10n/app_localizations.dart';
import '../data/market_api.dart';
import '../domain/market.dart';
import 'labels.dart';
import 'widgets/asset_avatar.dart';
import 'widgets/key_figures.dart';
import 'widgets/price_change.dart';
import 'widgets/price_chart.dart';

class AssetScreen extends ConsumerStatefulWidget {
  const AssetScreen({super.key, required this.assetId});

  final int assetId;

  @override
  ConsumerState<AssetScreen> createState() => _AssetScreenState();
}

class _AssetScreenState extends ConsumerState<AssetScreen> {
  String? _range;
  ChartMode _mode = ChartMode.line;
  bool _showFullDescription = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final detail = ref.watch(assetDetailProvider(widget.assetId));

    return Scaffold(
      appBar: AppBar(title: Text(detail.value?.asset.symbol ?? '')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Retry(
          message: apiErrorMessage(e, l10n),
          onRetry: () => ref.invalidate(assetDetailProvider(widget.assetId)),
        ),
        data: (d) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(assetDetailProvider(widget.assetId));
            await ref.read(assetDetailProvider(widget.assetId).future);
          },
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Header(detail: d),
                  const SizedBox(height: 16),
                  _chartSection(context, d),
                  const SizedBox(height: 16),
                  KeyFiguresCard(figures: buildKeyFigures(l10n, d)),
                  if (d.description != null) ...[
                    const SizedBox(height: 16),
                    _about(context, d.description!),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    '${l10n.dataSourceNote(d.dataSource)}\n${l10n.disclaimer}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chartSection(BuildContext context, AssetDetail d) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final range = _range ?? (d.ranges.contains('1M') ? '1M' : d.ranges.first);
    final history = ref.watch(assetHistoryProvider((widget.assetId, range)));

    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Wrap(
                      spacing: 6,
                      children: [
                        for (final r in d.ranges)
                          ChoiceChip(
                            label: Text(r),
                            selected: r == range,
                            onSelected: (_) => setState(() => _range = r),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SegmentedButton<ChartMode>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: ChartMode.line,
                      icon: const Icon(Icons.show_chart),
                      tooltip: l10n.chartLine,
                    ),
                    ButtonSegment(
                      value: ChartMode.candles,
                      icon: const Icon(Icons.candlestick_chart_outlined),
                      tooltip: l10n.chartCandles,
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => setState(() => _mode = s.first),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 260,
              child: history.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _Retry(
                  message: apiErrorMessage(e, l10n),
                  onRetry: () => ref.invalidate(
                    assetHistoryProvider((widget.assetId, range)),
                  ),
                ),
                data: (h) => h.candles.length < 2
                    ? Center(child: Text(l10n.chartEmpty))
                    : PriceChart(
                        history: h,
                        mode: _mode,
                        forex: d.asset.assetType == 'forex',
                      ),
              ),
            ),
            if (history.value?.changePercent case final change?) ...[
              const SizedBox(height: 8),
              Text(
                l10n.rangeChange(
                  formatPercent(change),
                  periodLabel(l10n, range),
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: changeColor(context, change),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (_mode == ChartMode.candles) ...[
              const SizedBox(height: 8),
              Text(l10n.chartCandlesHelp, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  Widget _about(BuildContext context, String description) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.aboutTitle, style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              maxLines: _showFullDescription ? null : 4,
              overflow: _showFullDescription ? null : TextOverflow.ellipsis,
            ),
            TextButton(
              onPressed: () =>
                  setState(() => _showFullDescription = !_showFullDescription),
              child: Text(_showFullDescription ? l10n.showLess : l10n.readMore),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.detail});

  final AssetDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final asset = detail.asset;
    final quote = asset.quote;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AssetAvatar(asset: asset, radius: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(asset.name, style: theme.textTheme.titleLarge),
                  ),
                  Text(
                    assetSubtitle(l10n, asset),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (quote == null)
          Text(l10n.priceUnavailable, style: theme.textTheme.titleMedium)
        else ...[
          Text(
            formatPrice(
              quote.price,
              quote.currency,
              forex: asset.assetType == 'forex',
            ),
            style: theme.textTheme.displaySmall,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PriceChange(
                percent: quote.changePercent,
                style: theme.textTheme.titleMedium,
              ),
              if (quote.marketOpen != null)
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(
                    Icons.circle,
                    size: 10,
                    color: quote.marketOpen!
                        ? changeColor(context, 1)
                        : theme.colorScheme.outline,
                  ),
                  label: Text(
                    quote.marketOpen! ? l10n.marketOpen : l10n.marketClosed,
                  ),
                ),
              Text(
                l10n.updatedAt(
                  DateFormat.MMMd().add_Hm().format(quote.asOf.toLocal()),
                ),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ErrorText(message),
            OutlinedButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      ),
    );
  }
}
