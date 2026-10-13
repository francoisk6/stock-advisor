// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Stock Adviser';

  @override
  String get homeWelcome => 'Welcome to your AI market copilot';

  @override
  String get homeSubtitle =>
      'Follow stocks and crypto you care about, with daily insights in plain language.';

  @override
  String get disclaimer =>
      'Educational information only — not financial advice.';

  @override
  String get backendStatusTitle => 'Server status';

  @override
  String backendStatusOk(String environment) {
    return 'Connected ($environment)';
  }

  @override
  String get backendStatusError => 'Cannot reach the server';

  @override
  String get retry => 'Retry';
}
