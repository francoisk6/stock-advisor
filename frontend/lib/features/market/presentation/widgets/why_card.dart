import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_error.dart';
import '../../../../core/format/numbers.dart';
import '../../../../core/widgets/error_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../copilot/presentation/rich_answer.dart';
import '../../../live/live_controller.dart';
import '../../data/market_api.dart';
import '../../domain/market.dart';

/// "Why is X up 3.2% today?" — shown on big moves; explains with today's headlines.
class WhyCard extends ConsumerStatefulWidget {
  const WhyCard({super.key, required this.asset});

  static const minMovePercent = 2.0;

  final Asset asset;

  @override
  ConsumerState<WhyCard> createState() => _WhyCardState();
}

class _WhyCardState extends ConsumerState<WhyCard> {
  Future<String>? _answer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final change = liveQuote(ref, widget.asset)?.changePercent;
    if (change == null || change.abs() < WhyCard.minMovePercent) {
      return const SizedBox.shrink();
    }
    final percent = formatPercent(change.abs(), signed: false);
    final title = change > 0
        ? l10n.whyTitleUp(widget.asset.symbol, percent)
        : l10n.whyTitleDown(widget.asset.symbol, percent);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.help_outline,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    header: true,
                    container: true,
                    child: Text(title, style: theme.textTheme.titleMedium),
                  ),
                ),
                if (_answer == null)
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: Text(l10n.whyExplain),
                    // Block body: a setState callback must not return the Future.
                    onPressed: () => setState(() {
                      _answer = ref
                          .read(marketApiProvider)
                          .whyMoved(widget.asset.id);
                    }),
                  ),
              ],
            ),
            if (_answer case final answer?)
              FutureBuilder<String>(
                future: answer,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(l10n.whyLoading)),
                        ],
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ErrorText(apiErrorMessage(snapshot.error!, l10n)),
                          TextButton(
                            onPressed: () => setState(() => _answer = null),
                            child: Text(l10n.retry),
                          ),
                        ],
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichAnswer(snapshot.data!),
                        const SizedBox(height: 8),
                        Text(l10n.whyNote, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
