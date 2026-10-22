import 'package:flutter/material.dart';

import '../../features/legal/presentation/legal_screen.dart';
import '../../l10n/app_localizations.dart';
import '../config/beta.dart';

/// Centered, narrow layout shared by the sign-in style screens (web and mobile).
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.footerNote,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  /// e.g. "By creating an account you agree to…", above the legal links.
  final String? footerNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.insights,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  ...children,
                  const SizedBox(height: 24),
                  if (isBeta)
                    Text(
                      AppLocalizations.of(context).betaNote,
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  if (footerNote != null)
                    Text(
                      footerNote!,
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  const LegalLinks(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
