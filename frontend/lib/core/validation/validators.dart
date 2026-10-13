import '../../l10n/app_localizations.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateEmail(String? value, AppLocalizations l10n) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return l10n.validationEmailRequired;
  if (!_emailPattern.hasMatch(email)) return l10n.validationEmailInvalid;
  return null;
}

/// Mirrors the backend rule: 8-128 chars with at least one letter and one digit.
String? validateNewPassword(String? value, AppLocalizations l10n) {
  final password = value ?? '';
  final ok =
      password.length >= 8 &&
      password.length <= 128 &&
      password.contains(RegExp(r'[A-Za-z]')) &&
      password.contains(RegExp(r'\d'));
  return ok ? null : l10n.validationPasswordRules;
}

String? validateRequiredPassword(String? value, AppLocalizations l10n) =>
    (value == null || value.isEmpty) ? l10n.validationPasswordRequired : null;
