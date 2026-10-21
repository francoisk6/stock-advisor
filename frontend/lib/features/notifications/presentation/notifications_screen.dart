import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/api_error.dart';
import '../../../core/widgets/error_text.dart';
import '../../../l10n/app_localizations.dart';
import '../data/notifications_api.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final inbox = ref.watch(notificationsProvider);
    final controller = ref.read(notificationsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notificationsTitle),
        actions: [
          if ((inbox.value?.unreadCount ?? 0) > 0)
            TextButton(
              onPressed: controller.markAllRead,
              child: Text(l10n.markAllRead),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(notificationsProvider.future),
            child: inbox.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ErrorText(apiErrorMessage(e, l10n)),
                  ),
                ],
              ),
              data: (data) => data.items.isEmpty
                  ? ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            l10n.notificationsEmpty,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      itemCount: data.items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final n = data.items[i];
                        return ListTile(
                          leading: Icon(
                            n.read
                                ? Icons.notifications_none
                                : Icons.notifications_active,
                            color: n.read ? null : theme.colorScheme.primary,
                          ),
                          title: Text(
                            n.title,
                            style: n.read
                                ? null
                                : const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${n.body}\n'
                            '${DateFormat.MMMd().add_Hm().format(n.createdAt.toLocal())}',
                          ),
                          isThreeLine: true,
                          onTap: () {
                            controller.markRead(n.id);
                            if (n.kind == 'digest') {
                              context.go('/brief');
                            } else if (n.kind == 'practice') {
                              context.go('/practice');
                            } else if (n.assetId != null) {
                              context.go('/assets/${n.assetId}');
                            }
                          },
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
