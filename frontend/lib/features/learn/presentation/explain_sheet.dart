import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../copilot/application/ask_copilot.dart';

/// "Explain this": what a figure means, with links to the glossary and the copilot.
///
/// [help] is the explanation for this spot; [termId] links the full glossary entry;
/// [question] (asked with [assetId] as context) offers "Ask the Copilot".
Future<void> showExplainSheet(
  BuildContext context, {
  required String title,
  String? value,
  required String help,
  String? termId,
  String? question,
  int? assetId,
}) {
  final router = GoRouter.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext);
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              if (value != null) ...[
                const SizedBox(height: 4),
                Text(value, style: theme.textTheme.titleMedium),
              ],
              const SizedBox(height: 16),
              Text(help, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  if (termId != null)
                    TextButton.icon(
                      icon: const Icon(Icons.menu_book_outlined),
                      label: Text(l10n.explainLearnMore),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        router.go('/learn/$termId');
                      },
                    ),
                  if (question != null)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.auto_awesome),
                      label: Text(l10n.termAskCopilot),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        // The screen below the sheet is still there to navigate from.
                        askCopilot(context, question, assetId: assetId);
                      },
                    ),
                  FilledButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: Text(l10n.gotIt),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
