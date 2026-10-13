/// Build-time configuration. Override with
/// `flutter run --dart-define=API_BASE_URL=https://...`.
class AppConfig {
  const AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8200/api/v1',
  );
}
