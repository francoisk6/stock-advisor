import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_error.dart';
import '../../../core/widgets/error_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../copilot/application/ask_copilot.dart';
import '../data/learn_api.dart';
import 'labels.dart';

/// Searchable list of investing terms, filterable by topic.
class GlossaryScreen extends ConsumerStatefulWidget {
  const GlossaryScreen({super.key});

  @override
  ConsumerState<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends ConsumerState<GlossaryScreen> {
  String _query = '';
  String? _category;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final glossary = ref.watch(glossaryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.glossaryTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l10n.glossarySearchHint,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final category in [null, ...glossaryCategories])
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: ChoiceChip(
                          label: Text(
                            category == null
                                ? l10n.glossaryAll
                                : categoryLabel(l10n, category),
                          ),
                          selected: _category == category,
                          onSelected: (_) =>
                              setState(() => _category = category),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: glossary.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ErrorText(apiErrorMessage(e, l10n)),
                        OutlinedButton(
                          onPressed: () => ref.invalidate(glossaryProvider),
                          child: Text(l10n.retry),
                        ),
                      ],
                    ),
                  ),
                  data: (terms) {
                    final shown = [
                      for (final t in terms)
                        if ((_category == null || t.category == _category) &&
                            t.matches(_query))
                          t,
                    ];
                    if (shown.isEmpty) {
                      return ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          Text(
                            l10n.glossaryEmpty(_query.trim()),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          if (_query.trim().isNotEmpty)
                            Center(
                              child: FilledButton.tonalIcon(
                                icon: const Icon(Icons.auto_awesome),
                                label: Text(l10n.termAskCopilot),
                                onPressed: () => askCopilot(
                                  context,
                                  l10n.glossaryAskUnknown(_query.trim()),
                                ),
                              ),
                            ),
                        ],
                      );
                    }
                    return ListView.separated(
                      itemCount: shown.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final t = shown[i];
                        return ListTile(
                          title: Text(t.term),
                          subtitle: Text(t.short),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.go('/learn/${t.id}'),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
