import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_error.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/error_text.dart';
import '../../../core/widgets/password_field.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/user.dart';
import '../../onboarding/presentation/profile_options.dart';
import '../data/user_api.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authControllerProvider).user;
    if (user == null) return const SizedBox.shrink(); // router is redirecting

    final profile = user.profile;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Section(
                title: l10n.profileAccount,
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      child: Text(user.displayName[0].toUpperCase()),
                    ),
                    title: Text(
                      user.fullName.isEmpty ? user.displayName : user.fullName,
                    ),
                    subtitle: Text(user.email),
                    trailing: IconButton(
                      tooltip: l10n.profileEditName,
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _editName(context, ref, user),
                    ),
                  ),
                  ListTile(
                    leading: Icon(
                      user.emailVerified
                          ? Icons.verified_outlined
                          : Icons.mark_email_unread,
                      color: user.emailVerified
                          ? theme.colorScheme.primary
                          : null,
                    ),
                    title: Text(
                      user.emailVerified
                          ? l10n.profileEmailVerified
                          : l10n.profileEmailNotVerified,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.workspace_premium_outlined),
                    title: Text(l10n.profilePlan(user.plan.name)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.key_outlined),
                    title: Text(l10n.profileSignInMethods),
                    subtitle: Text(
                      [
                        if (user.hasPassword) l10n.profileMethodPassword,
                        if (user.authProviders.contains('google'))
                          l10n.profileMethodGoogle,
                      ].join(' · '),
                    ),
                  ),
                ],
              ),
              _Section(
                title: l10n.profileInvesting,
                action: TextButton.icon(
                  onPressed: () => context.go('/onboarding?edit=1'),
                  icon: const Icon(Icons.tune),
                  label: Text(l10n.profileEdit),
                ),
                children: [
                  _InfoRow(
                    l10n.profileExperience,
                    optionLabel(
                      experienceOptions(l10n),
                      profile.experienceLevel,
                    ),
                  ),
                  _InfoRow(
                    l10n.profileRisk,
                    optionLabel(riskOptions(l10n), profile.riskProfile),
                  ),
                  _InfoRow(
                    l10n.profileHorizon,
                    optionLabel(
                      horizonOptions(l10n),
                      profile.investmentHorizon,
                    ),
                  ),
                  _InfoRow(
                    l10n.profileInterests,
                    profile.assetInterests
                        .map((c) => optionLabel(assetOptions(l10n), c))
                        .join(', '),
                  ),
                  _InfoRow(
                    l10n.profileMarkets,
                    profile.regionInterests
                        .map((c) => optionLabel(regionOptions(l10n), c))
                        .join(', '),
                  ),
                ],
              ),
              _Section(
                title: l10n.profileSecurity,
                children: [
                  ListTile(
                    leading: const Icon(Icons.password),
                    title: Text(
                      user.hasPassword
                          ? l10n.profileChangePassword
                          : l10n.profileSetPassword,
                    ),
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) =>
                          _ChangePasswordDialog(hasPassword: user.hasPassword),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: Text(l10n.profileSignOut),
                    onTap: () =>
                        ref.read(authControllerProvider.notifier).logout(),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.delete_forever_outlined,
                      color: theme.colorScheme.error,
                    ),
                    title: Text(
                      l10n.profileDeleteAccount,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) =>
                          _DeleteAccountDialog(hasPassword: user.hasPassword),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.disclaimer,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editName(BuildContext context, WidgetRef ref, User user) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: user.fullName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profileEditName),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 100,
          decoration: InputDecoration(labelText: l10n.fullNameLabel),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await ref.read(userApiProvider).updateName(name.trim());
      ref.read(authControllerProvider.notifier).setUser(updated);
      messenger.showSnackBar(SnackBar(content: Text(l10n.profileNameUpdated)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(e, l10n))));
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.action});

  final String title;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: theme.colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title, style: theme.textTheme.titleMedium),
                    ),
                    ?action,
                  ],
                ),
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? '—' : value)),
        ],
      ),
    );
  }
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog({required this.hasPassword});

  final bool hasPassword;

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await ref
          .read(userApiProvider)
          .changePassword(
            currentPassword: widget.hasPassword ? _current.text : null,
            newPassword: _new.text,
          );
      await ref.read(authControllerProvider.notifier).replaceSession(session);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.passwordChanged)));
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e, l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(
        widget.hasPassword
            ? l10n.profileChangePassword
            : l10n.profileSetPassword,
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.hasPassword) ...[
                PasswordField(
                  controller: _current,
                  label: l10n.currentPasswordLabel,
                  autofillHints: const [AutofillHints.password],
                  validator: (v) => validateRequiredPassword(v, l10n),
                ),
                const SizedBox(height: 16),
              ],
              PasswordField(
                controller: _new,
                label: l10n.newPasswordLabel,
                helperText: l10n.passwordRulesHint,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                validator: (v) => validateNewPassword(v, l10n),
              ),
              const SizedBox(height: 16),
              ErrorText(_error),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _busy ? null : _submit, child: Text(l10n.save)),
      ],
    );
  }
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog({required this.hasPassword});

  final bool hasPassword;

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final navigator = Navigator.of(context);
      await ref
          .read(authControllerProvider.notifier)
          .deleteAccount(password: widget.hasPassword ? _password.text : null);
      navigator.pop();
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e, l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: colors.error),
      title: Text(l10n.deleteAccountTitle),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.deleteAccountBody),
            if (widget.hasPassword) ...[
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                label: l10n.deleteAccountConfirmPassword,
                textInputAction: TextInputAction.done,
              ),
            ],
            const SizedBox(height: 16),
            ErrorText(_error),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          onPressed: _busy ? null : _delete,
          child: Text(l10n.deleteAccountButton),
        ),
      ],
    );
  }
}
