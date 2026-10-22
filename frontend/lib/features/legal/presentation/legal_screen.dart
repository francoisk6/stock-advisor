import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/error_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../copilot/presentation/rich_answer.dart';

const legalDocs = {'privacy', 'terms', 'disclaimer'};

/// Privacy policy, terms and disclaimer (Markdown in assets/legal/en/), signed in or out.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.doc});

  final String doc;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = switch (doc) {
      'privacy' => l10n.legalPrivacyTitle,
      'terms' => l10n.legalTermsTitle,
      _ => l10n.legalDisclaimer,
    };
    final text = legalDocs.contains(doc)
        ? DefaultAssetBundle.of(context).loadString('assets/legal/en/$doc.md')
        : Future<String>.error('unknown');
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        // Opened from an email or a typed link there's nothing to go back to.
        leading: context.canPop()
            ? null
            : IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                icon: const Icon(Icons.close),
                onPressed: () => context.go('/'),
              ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: FutureBuilder<String>(
            future: text,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: ErrorText(l10n.errorNotAvailable),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              // The page title is in the app bar; skip the file's own "# Title" line.
              final body = snapshot.data!.replaceFirst(RegExp(r'^# .*\n+'), '');
              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                children: [
                  RichAnswer(body),
                  const SizedBox(height: 16),
                  const LegalLinks(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// "Privacy · Terms · Disclaimer" links for the sign-in screens and Profile.
class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        for (final (doc, label) in [
          ('privacy', l10n.legalPrivacy),
          ('terms', l10n.legalTerms),
          ('disclaimer', l10n.legalDisclaimer),
        ])
          TextButton(
            onPressed: () => context.push('/legal/$doc'),
            child: Text(label),
          ),
      ],
    );
  }
}
