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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
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
      // On success the router redirects away from this screen.
      await ref
          .read(authControllerProvider.notifier)
          .login(_email.text, _password.text);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AuthScaffold(
      title: l10n.loginTitle,
      subtitle: l10n.loginSubtitle,
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  validator: (v) => validateRequiredPassword(v, l10n),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: () => context.go('/forgot-password'),
                    child: Text(l10n.loginForgotPassword),
                  ),
                ),
                const SizedBox(height: 8),
                ErrorText(_error),
                BusyButton(
                  label: l10n.loginButton,
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
            Text(l10n.loginNoAccount),
            TextButton(
              onPressed: () => context.go('/register'),
              child: Text(l10n.loginCreateAccount),
            ),
          ],
        ),
      ],
    );
  }
}
