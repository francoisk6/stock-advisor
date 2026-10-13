import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/google_sign_in_service.dart';

/// Calls [onIdToken] with a Google ID token after the user picks an account.
class GoogleSignInButton extends ConsumerStatefulWidget {
  const GoogleSignInButton({
    super.key,
    required this.onIdToken,
    required this.onError,
  });

  final Future<void> Function(String idToken) onIdToken;
  final void Function(Object error) onError;

  @override
  ConsumerState<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends ConsumerState<GoogleSignInButton> {
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      final token = await ref.read(googleSignInServiceProvider).authenticate();
      if (token != null) await widget.onIdToken(token);
    } catch (e) {
      widget.onError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _busy ? null : _signIn,
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      icon: const Icon(Icons.account_circle_outlined),
      label: Text(AppLocalizations.of(context).googleContinue),
    );
  }
}
