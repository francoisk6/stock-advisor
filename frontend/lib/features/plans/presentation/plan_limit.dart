import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';

/// "See plans" under a limit message.
class SeePlansButton extends StatelessWidget {
  const SeePlansButton({super.key, this.beforeOpening});

  /// e.g. close the sheet the button is in.
  final VoidCallback? beforeOpening;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        icon: const Icon(Icons.workspace_premium_outlined),
        label: Text(AppLocalizations.of(context).seePlans),
        onPressed: () {
          beforeOpening?.call();
          router.go('/plans');
        },
      ),
    );
  }
}

/// A plan limit was reached: explain (the server's message) and offer the Plans screen.
Future<void> showPlanLimit(BuildContext context, String message) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true, // above the tab bar
      showDragHandle: true,
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext);
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.planLimitTitle, style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(message, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: Text(l10n.gotIt),
                    ),
                    FilledButton.icon(
                      icon: const Icon(Icons.workspace_premium_outlined),
                      label: Text(l10n.seePlans),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        GoRouter.of(context).go('/plans');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
