import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/auth_controller.dart';
import '../../data/google_sign_in_service.dart';
import 'google_sign_in_button.dart';

/// "or" divider + Google button, hidden when Google sign-in isn't configured.
class GoogleSection extends ConsumerWidget {
  const GoogleSection({super.key, required this.onError});

  final void Function(Object error) onError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(googleSignInServiceProvider).enabled) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(l10n.orDivider),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        GoogleSignInButton(
          onIdToken: (token) =>
              ref.read(authControllerProvider.notifier).loginWithGoogle(token),
          onError: onError,
        ),
      ],
    );
  }
}
