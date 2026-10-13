import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_error.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/auth_scaffold.dart';
import '../../../core/widgets/busy_button.dart';
import '../../../core/widgets/error_text.dart';
import '../../../core/widgets/password_field.dart';
import '../../../l10n/app_localizations.dart';
import '../data/auth_api.dart';

/// Opened from the link in the reset email: /reset-password?token=...
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.token});

  final String? token;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authApiProvider)
          .resetPassword(token: widget.token!, newPassword: _password.text);
      setState(() => _done = true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = apiErrorMessage(e, AppLocalizations.of(context)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final token = widget.token;

    if (token == null || token.isEmpty) {
      return AuthScaffold(
        title: l10n.verifyFailedTitle,
        subtitle: l10n.linkIncomplete,
        children: [
          TextButton(
            onPressed: () => context.go('/login'),
            child: Text(l10n.backToLogin),
          ),
        ],
      );
    }

    if (_done) {
      return AuthScaffold(
        title: l10n.resetTitle,
        subtitle: l10n.resetSuccess,
        children: [
          FilledButton(
            onPressed: () => context.go('/login'),
            child: Text(l10n.loginButton),
          ),
        ],
      );
    }

    return AuthScaffold(
      title: l10n.resetTitle,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PasswordField(
                controller: _password,
                label: l10n.newPasswordLabel,
                helperText: l10n.passwordRulesHint,
                autofillHints: const [AutofillHints.newPassword],
                validator: (v) => validateNewPassword(v, l10n),
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _confirm,
                label: l10n.confirmPasswordLabel,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                validator: (v) => v == _password.text
                    ? null
                    : l10n.validationPasswordsDontMatch,
              ),
              const SizedBox(height: 16),
              ErrorText(_error),
              BusyButton(
                label: l10n.resetButton,
                busy: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => context.go('/login'),
          child: Text(l10n.backToLogin),
        ),
      ],
    );
  }
}
