import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/widgets/verify_email_banner.dart';
import '../../health/presentation/backend_status_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.profileTitle,
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.go('/profile'),
          ),
        ],
      ),
      body: Column(
        children: [
          const VerifyEmailBanner(),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      user == null
                          ? l10n.appTitle
                          : l10n.homeGreeting(user.displayName),
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.homeSubtitle, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 24),
                    Card(
                      color: theme.colorScheme.secondaryContainer,
                      child: ListTile(
                        leading: const Icon(Icons.upcoming_outlined),
                        title: Text(l10n.homeComingSoonTitle),
                        subtitle: Text(l10n.homeComingSoonBody),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const BackendStatusCard(),
                    const SizedBox(height: 24),
                    Text(
                      l10n.disclaimer,
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
