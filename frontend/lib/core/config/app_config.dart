/// Build-time configuration. Override with `--dart-define`, e.g.
/// `flutter run --dart-define=API_BASE_URL=https://... --dart-define=GOOGLE_WEB_CLIENT_ID=...`.
class AppConfig {
  const AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8200/api/v1',
  );

  /// OAuth "Web application" client id from Google Cloud. Empty hides Google sign-in.
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );
}
