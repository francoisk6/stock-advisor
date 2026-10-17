import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_error.dart';
import '../../../core/widgets/error_text.dart';
import '../../../l10n/app_localizations.dart';
import '../data/brief_api.dart';

/// Home card: today's brief preview, or a button to write it now.
class BriefCard extends ConsumerWidget {
  const BriefCard({super.key});

  /// First few plain lines, without markdown symbols or links' URLs.
  static String preview(String content) {
    final lines = content
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'^[#\-*\s]+'), '').trim())
        .where((l) => l.isNotEmpty)
        .take(3)
        .join(' · ');
    return lines.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]+\)'),
      (m) => m.group(1)!,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final brief = ref.watch(briefProvider);

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.wb_sunny_outlined,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    header: true,
                    container: true,
                    child: Text(
                      l10n.briefTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (brief.isLoading)
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(l10n.briefWriting)),
                ],
              )
            else if (brief.value case final b?) ...[
              Text(
                preview(b.content),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => context.go('/brief'),
                  child: Text(l10n.briefRead),
                ),
              ),
            ] else ...[
              if (brief.hasError)
                ErrorText(apiErrorMessage(brief.error!, l10n)),
              Text(l10n.briefNone),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.tonal(
                  onPressed: () => ref.read(briefProvider.notifier).create(),
                  child: Text(l10n.briefGet),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
