import 'package:flutter/material.dart';

import '../../../../core/format/numbers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../learn/presentation/explain_sheet.dart';
import '../../domain/market.dart';
import '../labels.dart';

/// A row in "Key figures": label, formatted value, and an explanation for beginners.
class KeyFigure {
  const KeyFigure(this.key, this.label, this.value, this.help);

  final String key;
  final String label;
  final String value;
  final String help;
}

/// Turns raw stats into display rows; low/high pairs become one "range" row.
List<KeyFigure> buildKeyFigures(AppLocalizations l, AssetDetail detail) {
  final stats = {for (final s in detail.stats) s.key: s};
  final currency = detail.asset.quote?.currency ?? detail.asset.currency;
  final crypto = detail.asset.assetType == 'crypto';
  final forex = detail.asset.assetType == 'forex';

  String format(Stat s) {
    final v = s.value;
    if (v is String) return v;
    final n = (v as num).toDouble();
    return switch (s.unit) {
      'money' => formatPrice(n, currency, forex: forex),
      'percent' => formatPercent(n, signed: s.key == 'from_all_time_high'),
      'compact' =>
        (s.key == 'market_cap' || s.key == 'volume_24h') && currency != null
            ? formatCompactMoney(n, currency)
            : formatCompact(n),
      _ => s.key == 'market_cap_rank' ? '#${n.round()}' : formatNumber(n),
    };
  }

  final rows = <KeyFigure>[];
  void add(String key, String value) {
    final text = statText(l, key, crypto: crypto);
    if (text != null) rows.add(KeyFigure(key, text.$1, value, text.$2));
  }

  for (final pair in [
    ('day_range', 'day_low', 'day_high'),
    ('week52_range', 'week52_low', 'week52_high'),
  ]) {
    final low = stats.remove(pair.$2);
    final high = stats.remove(pair.$3);
    if (low != null && high != null) {
      add(pair.$1, '${format(low)} – ${format(high)}');
    }
  }
  for (final stat in stats.values) {
    add(stat.key, format(stat));
  }
  // Ranges read best after the headline numbers (stable sort keeps the rest in order).
  const ranges = {'day_range', 'week52_range'};
  final ordered = [
    ...rows.where((r) => !ranges.contains(r.key)),
    ...rows.where((r) => ranges.contains(r.key)),
  ];
  rows
    ..clear()
    ..addAll(ordered);
  return rows;
}

class KeyFiguresCard extends StatelessWidget {
  const KeyFiguresCard({super.key, required this.figures, required this.asset});

  final List<KeyFigure> figures;
  final Asset asset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: Semantics(
                header: true,
                container: true,
                child: Text(
                  l10n.keyFigures,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              subtitle: Text(l10n.keyFiguresHint),
            ),
            for (final f in figures)
              ListTile(
                dense: true,
                title: Text(f.label),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      f.value,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
                onTap: () => showExplainSheet(
                  context,
                  title: f.label,
                  value: f.value,
                  help: f.help,
                  termId: statTerm(f.key),
                  question: l10n.explainFigureQuestion(
                    asset.symbol,
                    f.label,
                    f.value,
                  ),
                  assetId: asset.id,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
