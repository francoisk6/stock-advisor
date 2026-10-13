import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../health/presentation/backend_status_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.homeWelcome, style: textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(l10n.homeSubtitle, style: textTheme.bodyLarge),
              const SizedBox(height: 24),
              const BackendStatusCard(),
              const SizedBox(height: 24),
              Text(
                l10n.disclaimer,
                style: textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
