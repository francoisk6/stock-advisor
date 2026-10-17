import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/api_error.dart';
import '../../../core/widgets/error_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../copilot/presentation/rich_answer.dart';
import '../data/brief_api.dart';
import 'brief_card.dart';

class BriefScreen extends ConsumerWidget {
  const BriefScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final brief = ref.watch(briefProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.briefTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: brief.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: ErrorText(apiErrorMessage(e, l10n)),
            ),
            data: (b) => b == null
                ? const Padding(padding: EdgeInsets.all(16), child: BriefCard())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        l10n.briefWritten(
                          DateFormat.MMMEd().add_Hm().format(
                            b.createdAt.toLocal(),
                          ),
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      RichAnswer(b.content),
                      const SizedBox(height: 24),
                      Text(l10n.briefNote, style: theme.textTheme.bodySmall),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
