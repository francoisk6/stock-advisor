import 'package:flutter/foundation.dart';

/// Build-time configuration. Override with `--dart-define`, e.g.
/// `flutter run --dart-define=API_BASE_URL=https://... --dart-define=GOOGLE_WEB_CLIENT_ID=...`.
class AppConfig {
  const AppConfig._();

  static const _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

  /// Without an override, the web app calls port 8200 on the host it was opened from, so the
  /// same build works via `localhost` and via the server's LAN IP.
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    if (kIsWeb) return '${Uri.base.scheme}://${Uri.base.host}:8200/api/v1';
    return 'http://localhost:8200/api/v1';
  }

  /// OAuth "Web application" client id from Google Cloud. Empty hides Google sign-in.
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  /// Google only accepts `localhost` or real domains as web origins, never raw IPs.
  static bool get googleSignInAllowedHere =>
      !kIsWeb ||
      !RegExp(r'^[\d.]+$|^\[?[0-9a-fA-F:]+\]?$').hasMatch(Uri.base.host);
}
