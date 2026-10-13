import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_error.dart';
import '../../../core/widgets/auth_scaffold.dart';
import '../../../l10n/app_localizations.dart';
import '../application/auth_controller.dart';
import '../data/auth_api.dart';

/// Opened from the confirmation email: /verify-email?token=... Works signed in or out.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.token});

  final String? token;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  late final Future<void> _result = _verify();

  Future<void> _verify() async {
    final token = widget.token;
    if (token == null || token.isEmpty) throw const _MissingToken();
    await ref.read(authApiProvider).verifyEmail(token);
    // Refresh the "verified" badge if this device is signed in; ignore failures.
    await ref
        .read(authControllerProvider.notifier)
        .reloadUser()
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final signedIn = ref.watch(authControllerProvider).isAuthenticated;

    return FutureBuilder<void>(
      future: _result,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return AuthScaffold(
            title: l10n.verifyInProgress,
            children: const [Center(child: CircularProgressIndicator())],
          );
        }
        final error = snapshot.error;
        final continueButton = FilledButton(
          onPressed: () => context.go(signedIn ? '/' : '/login'),
          child: Text(signedIn ? l10n.continueButton : l10n.loginButton),
        );
        if (error != null) {
          return AuthScaffold(
            title: l10n.verifyFailedTitle,
            subtitle: error is _MissingToken
                ? l10n.linkIncomplete
                : apiErrorMessage(error, l10n),
            children: [continueButton],
          );
        }
        return AuthScaffold(
          title: l10n.verifySuccessTitle,
          subtitle: l10n.verifySuccessBody,
          children: [continueButton],
        );
      },
    );
  }
}

class _MissingToken implements Exception {
  const _MissingToken();
}
