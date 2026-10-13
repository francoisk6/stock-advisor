import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/app_config.dart';

/// Wraps the google_sign_in plugin. Web renders Google's own button and reports sign-ins
/// through [events]; Android calls [authenticate]. Both yield an ID token for our backend.
class GoogleSignInService {
  Future<void>? _init;

  bool get enabled => AppConfig.googleWebClientId.isNotEmpty;

  Future<void> ensureInitialized() {
    return _init ??= GoogleSignIn.instance.initialize(
      // Web uses the client id directly; Android needs it as the server client id so the
      // ID token's audience is the web client our backend accepts.
      clientId: kIsWeb ? AppConfig.googleWebClientId : null,
      serverClientId: kIsWeb ? null : AppConfig.googleWebClientId,
    );
  }

  Stream<GoogleSignInAuthenticationEvent> get events =>
      GoogleSignIn.instance.authenticationEvents;

  bool get supportsAuthenticate => GoogleSignIn.instance.supportsAuthenticate();

  /// Interactive sign-in (Android/iOS). Returns the ID token, or null if the user cancelled.
  Future<String?> authenticate() async {
    await ensureInitialized();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (!enabled || _init == null) return;
    try {
      await GoogleSignIn.instance.signOut();
    } on Exception {
      // Signing out of Google is best-effort; our own session is already cleared.
    }
  }
}

final googleSignInServiceProvider = Provider<GoogleSignInService>(
  (ref) => GoogleSignInService(),
);
