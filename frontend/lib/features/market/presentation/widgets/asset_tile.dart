import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/numbers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../live/live_controller.dart';
import '../../domain/market.dart';
import '../labels.dart';
import 'asset_avatar.dart';
import 'price_change.dart';

class AssetTile extends ConsumerWidget {
  const AssetTile({super.key, required this.asset, required this.onTap});

  final Asset asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final quote = liveQuote(ref, asset);
    final subtitle = assetSubtitle(l10n, asset);

    return ListTile(
      onTap: onTap,
      leading: AssetAvatar(asset: asset),
      title: Text(asset.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: quote == null
          ? null
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatPrice(
                    quote.price,
                    quote.currency,
                    forex: asset.assetType == 'forex',
                  ),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                PriceChange(
                  percent: quote.changePercent,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
    );
  }
}
