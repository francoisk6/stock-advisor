import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/numbers.dart';
import '../../../l10n/app_localizations.dart';
import '../../market/domain/market.dart';
import '../data/practice_api.dart';
import 'trade_sheet.dart';

/// "Practice" on an asset page: what the practice account holds, and buy/sell buttons.
class PracticeCard extends ConsumerWidget {
  const PracticeCard({super.key, required this.asset});

  final Asset asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final position = ref.watch(practiceProvider).value?.positionOf(asset.id);
    final index = asset.assetType == 'index';
    final value = position?.valueUsd;

    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              container: true,
              child: Text(
                l10n.practiceTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              index
                  ? l10n.practiceIndexNote
                  : position == null
                  ? l10n.practiceCardBody
                  : l10n.practiceCardHeld(
                      '${formatQuantity(position.quantity)} ${asset.symbol}',
                      value == null ? '—' : formatMoney(value, 'USD'),
                    ),
            ),
            if (!index) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.add_shopping_cart),
                    label: Text(l10n.practiceBuy),
                    onPressed: () => TradeSheet.show(context, asset, 'buy'),
                  ),
                  if (position != null)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.sell_outlined),
                      label: Text(l10n.practiceSell),
                      onPressed: () => TradeSheet.show(context, asset, 'sell'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
