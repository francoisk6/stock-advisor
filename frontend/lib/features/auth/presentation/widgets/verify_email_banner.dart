import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_error.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/auth_controller.dart';
import '../../data/auth_api.dart';

/// Reminds users who signed up with a password to confirm their email.
class VerifyEmailBanner extends ConsumerWidget {
  const VerifyEmailBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null || user.emailVerified) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);

    return MaterialBanner(
      leading: const Icon(Icons.mark_email_unread_outlined),
      content: Text(l10n.verifyBannerText(user.email)),
      actions: [
        TextButton(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              final message = await ref
                  .read(authApiProvider)
                  .resendVerification();
              messenger.showSnackBar(SnackBar(content: Text(message)));
            } catch (e) {
              messenger.showSnackBar(
                SnackBar(content: Text(apiErrorMessage(e, l10n))),
              );
            }
          },
          child: Text(l10n.verifyBannerResend),
        ),
      ],
    );
  }
}
