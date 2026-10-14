import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_error.dart';
import '../../../core/widgets/error_text.dart';
import '../../../l10n/app_localizations.dart';
import '../data/alerts_api.dart';
import 'alert_tile.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final alerts = ref.watch(alertsProvider(null));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.alertsTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: alerts.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: ErrorText(apiErrorMessage(e, l10n)),
            ),
            data: (items) => items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l10n.alertsEmpty, textAlign: TextAlign.center),
                  )
                : ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(l10n.alertsIntro),
                      ),
                      for (final alert in items)
                        AlertTile(
                          alert: alert,
                          showAsset: true,
                          onTap: () => context.go('/assets/${alert.asset.id}'),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
