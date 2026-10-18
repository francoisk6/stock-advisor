import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_error.dart';
import '../../../core/widgets/error_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../copilot/application/ask_copilot.dart';
import '../data/learn_api.dart';
import 'labels.dart';

/// One glossary entry: summary, explanation, example and related terms.
class TermScreen extends ConsumerWidget {
  const TermScreen({super.key, required this.termId});

  final String termId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final glossary = ref.watch(glossaryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.glossaryTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: glossary.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: ErrorText(apiErrorMessage(e, l10n)),
            ),
            data: (terms) {
              final byId = {for (final t in terms) t.id: t};
              final term = byId[termId];
              if (term == null) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: ErrorText(l10n.termNotFound),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    categoryLabel(l10n, term.category),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Semantics(
                    header: true,
                    container: true,
                    child: Text(
                      term.term,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(term.short, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 16),
                  Text(term.body, style: theme.textTheme.bodyLarge),
                  if (term.example != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: theme.colorScheme.surfaceContainerLow,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.termExample,
                              style: theme.textTheme.labelLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(term.example!),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FilledButton.tonalIcon(
                      icon: const Icon(Icons.auto_awesome),
                      label: Text(l10n.termAskCopilot),
                      onPressed: () =>
                          askCopilot(context, l10n.termQuestion(term.term)),
                    ),
                  ),
                  if (term.related.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Semantics(
                      header: true,
                      container: true,
                      child: Text(
                        l10n.termRelated,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final id in term.related)
                          if (byId[id] case final related?)
                            // Buttons, not ActionChips: Flutter web announces chips as checkboxes.
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => context.go('/learn/$id'),
                              child: Text(related.term),
                            ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
