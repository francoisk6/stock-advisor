import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/live/live_controller.dart';
import 'l10n/app_localizations.dart';

final _messengerKey = GlobalKey<ScaffoldMessengerState>();

class StockAdviserApp extends ConsumerWidget {
  const StockAdviserApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Keeps the live connection alive and pops up alerts as they arrive.
    ref.listen(liveControllerProvider.select((s) => s.lastNotification), (
      previous,
      next,
    ) {
      final messenger = _messengerKey.currentState;
      final l10n = messenger == null
          ? null
          : AppLocalizations.of(messenger.context);
      if (next == null ||
          next.id == previous?.id ||
          messenger == null ||
          l10n == null) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(next.title),
          duration: const Duration(seconds: 8),
          action: next.assetId == null
              ? null
              : SnackBarAction(
                  label: l10n.viewAction,
                  onPressed: () => router.go('/assets/${next.assetId}'),
                ),
        ),
      );
    });

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      scaffoldMessengerKey: _messengerKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
