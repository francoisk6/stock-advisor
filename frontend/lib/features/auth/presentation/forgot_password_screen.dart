import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_error.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/auth_scaffold.dart';
import '../../../core/widgets/busy_button.dart';
import '../../../core/widgets/error_text.dart';
import '../../../l10n/app_localizations.dart';
import '../data/auth_api.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _sentMessage;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final message = await ref
          .read(authApiProvider)
          .forgotPassword(_email.text.trim());
      setState(() => _sentMessage = message);
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
    return AuthScaffold(
      title: l10n.forgotTitle,
      subtitle: _sentMessage == null ? l10n.forgotSubtitle : null,
      children: [
        if (_sentMessage != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.mark_email_read_outlined),
              title: Text(_sentMessage!),
            ),
          )
        else
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: l10n.emailLabel,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => validateEmail(v, l10n),
                ),
                const SizedBox(height: 16),
                ErrorText(_error),
                BusyButton(
                  label: l10n.forgotButton,
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
