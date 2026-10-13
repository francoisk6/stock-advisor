import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../data/health_repository.dart';

class BackendStatusCard extends ConsumerWidget {
  const BackendStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final health = ref.watch(healthStatusProvider);

    return Card(
      color: colors.surfaceContainerHighest,
      child: ListTile(
        title: Text(l10n.backendStatusTitle),
        subtitle: health.when(
          data: (h) => Text(l10n.backendStatusOk(h.environment)),
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => Text(l10n.backendStatusError),
        ),
        leading: health.when(
          data: (_) => Icon(Icons.check_circle, color: colors.primary),
          loading: () => const Icon(Icons.hourglass_empty),
          error: (_, _) => Icon(Icons.error, color: colors.error),
        ),
        trailing: health.hasError
            ? TextButton(
                onPressed: () => ref.invalidate(healthStatusProvider),
                child: Text(l10n.retry),
              )
            : null,
      ),
    );
  }
}
