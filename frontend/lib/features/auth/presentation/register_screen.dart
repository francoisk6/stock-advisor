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
import '../application/auth_controller.dart';
import 'widgets/google_section.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _showError(Object error) {
    if (mounted) {
      setState(
        () => _error = apiErrorMessage(error, AppLocalizations.of(context)),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // On success the router sends the new user to onboarding.
      await ref
          .read(authControllerProvider.notifier)
          .register(_email.text, _password.text, _name.text);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AuthScaffold(
      title: l10n.registerTitle,
      subtitle: l10n.registerSubtitle,
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  autofillHints: const [AutofillHints.name],
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: l10n.fullNameLabel,
                    border: const OutlineInputBorder(),
                    counterText: '',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l10n.validationNameRequired
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.emailLabel,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => validateEmail(v, l10n),
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _password,
                  label: l10n.passwordLabel,
                  helperText: l10n.passwordRulesHint,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  validator: (v) => validateNewPassword(v, l10n),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.registerTerms,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                ErrorText(_error),
                BusyButton(
                  label: l10n.registerButton,
                  busy: _busy,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
        GoogleSection(onError: _showError),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.registerHaveAccount),
            TextButton(
              onPressed: () => context.go('/login'),
              child: Text(l10n.registerSignIn),
            ),
          ],
        ),
      ],
    );
  }
}
