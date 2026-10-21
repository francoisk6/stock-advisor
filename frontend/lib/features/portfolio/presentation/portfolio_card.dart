import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/numbers.dart';
import '../../../l10n/app_localizations.dart';
import '../../market/domain/market.dart';
import '../data/portfolio_api.dart';
import 'holding_sheet.dart';

/// "My portfolio" on an asset page: what the user owns of it, with add/edit.
class PortfolioCard extends ConsumerWidget {
  const PortfolioCard({super.key, required this.asset});

  final Asset asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (asset.assetType == 'index') return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final portfolio = ref.watch(portfolioProvider).value;
    final holding = portfolio?.holdingOf(asset.id);
    final value = holding?.value;

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
                l10n.portfolioTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              holding == null
                  ? l10n.portfolioCardBody
                  : l10n.portfolioCardHeld(
                      '${formatQuantity(holding.quantity)} ${asset.symbol}',
                      value == null
                          ? '—'
                          : formatMoney(value, portfolio!.currency),
                    ),
            ),
            const SizedBox(height: 12),
            holding == null
                ? FilledButton.tonalIcon(
                    icon: const Icon(Icons.add),
                    label: Text(l10n.portfolioCardAdd),
                    onPressed: () => HoldingSheet.show(context, asset),
                  )
                : OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(l10n.portfolioCardEdit),
                    onPressed: () =>
                        HoldingSheet.show(context, asset, holding: holding),
                  ),
          ],
        ),
      ),
    );
  }
}
