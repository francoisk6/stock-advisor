import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/time_ago.dart';
import '../../../../core/widgets/open_link.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/market_api.dart';

class NewsCard extends ConsumerWidget {
  const NewsCard({super.key, required this.assetId});

  final int assetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final news = ref.watch(assetNewsProvider(assetId));

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
                child: Text(l10n.newsTitle, style: theme.textTheme.titleMedium),
              ),
            ),
            ...news.when(
              loading: () => const [LinearProgressIndicator()],
              // News is a bonus: failures just hide the list.
              error: (_, _) => [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(l10n.newsEmpty),
                ),
              ],
              data: (items) => items.isEmpty
                  ? [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(l10n.newsEmpty),
                      ),
                    ]
                  : [
                      for (final item in items.take(6))
                        ListTile(
                          title: Text(item.title, maxLines: 3),
                          subtitle: Text(
                            l10n.newsSourceTime(
                              item.source,
                              timeAgo(l10n, item.publishedAt),
                            ),
                          ),
                          trailing: const Icon(Icons.open_in_new, size: 18),
                          onTap: () => openLink(item.url),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                        child: Text(
                          l10n.newsNote,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}
