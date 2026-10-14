import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/api_error.dart';
import '../../../core/widgets/snack.dart';
import '../../../l10n/app_localizations.dart';
import '../data/alerts_api.dart';
import '../domain/alert.dart';
import 'alert_text.dart';

/// One alert with an on/off switch and delete; [showAsset] adds the asset name (alerts list).
class AlertTile extends ConsumerWidget {
  const AlertTile({
    super.key,
    required this.alert,
    this.showAsset = false,
    this.onTap,
  });

  final PriceAlert alert;
  final bool showAsset;
  final VoidCallback? onTap;

  void _refresh(WidgetRef ref) {
    ref.invalidate(alertsProvider(alert.asset.id));
    ref.invalidate(alertsProvider(null));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final description = alertDescription(
      l10n,
      alert.kind,
      alert.threshold,
      alert.asset.quote?.currency ?? alert.asset.currency,
      forex: alert.asset.assetType == 'forex',
    );
    final fired = alert.lastTriggeredAt;
    final status = [
      if (!alert.isActive) l10n.alertOffLabel,
      if (fired != null)
        l10n.alertLastFired(DateFormat.MMMd().add_Hm().format(fired.toLocal())),
    ].join(' · ');

    Future<void> run(Future<void> Function() action, [String? done]) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await action();
        _refresh(ref);
        if (done != null) showSnack(messenger, done);
      } catch (e) {
        showSnack(messenger, apiErrorMessage(e, l10n));
      }
    }

    return ListTile(
      onTap: onTap,
      leading: Icon(
        alert.isActive
            ? Icons.notifications_active_outlined
            : Icons.notifications_off_outlined,
      ),
      title: Text(
        showAsset ? '${alert.asset.name} (${alert.asset.symbol})' : description,
      ),
      subtitle: Text(
        [if (showAsset) description, if (status.isNotEmpty) status].join('\n'),
      ),
      isThreeLine: showAsset && status.isNotEmpty,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: alert.isActive,
            onChanged: (on) =>
                run(() => ref.read(alertsApiProvider).setActive(alert.id, on)),
          ),
          IconButton(
            tooltip: l10n.alertDelete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => run(
              () => ref.read(alertsApiProvider).delete(alert.id),
              l10n.alertDeleted,
            ),
          ),
        ],
      ),
    );
  }
}
