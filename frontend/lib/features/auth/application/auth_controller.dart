import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/data/user_api.dart';
import '../data/auth_api.dart';
import '../data/google_sign_in_service.dart';
import '../data/token_store.dart';
import '../domain/auth_state.dart';
import '../domain/user.dart';

/// Single source of truth for "who is signed in". The router redirects based on this state.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(_restoreSession);
    return const AuthState.unknown();
  }

  TokenStore get _tokens => ref.read(tokenStoreProvider);
  AuthApi get _authApi => ref.read(authApiProvider);

  Future<void> _restoreSession() async {
    await _tokens.load();
    final refresh = _tokens.refreshToken;
    if (refresh == null) {
      state = const AuthState.unauthenticated();
      return;
    }
    try {
      await _applySession(await _authApi.refresh(refresh));
    } on DioException catch (e) {
      // Expired/revoked session: forget it. Server unreachable: show sign-in but keep the
      // saved tokens, so reloading the app once the server is back restores the session.
      if (e.response?.statusCode == 401) await _tokens.clear();
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> _applySession(AuthSession session) async {
    await _tokens.save(
      access: session.accessToken,
      refresh: session.refreshToken,
    );
    state = AuthState.authenticated(session.user);
  }

  Future<void> login(String email, String password) async => _applySession(
    await _authApi.login(email: email.trim(), password: password),
  );

  Future<void> register(String email, String password, String fullName) async =>
      _applySession(
        await _authApi.register(
          email: email.trim(),
          password: password,
          fullName: fullName.trim(),
        ),
      );

  Future<void> loginWithGoogle(String idToken) async =>
      _applySession(await _authApi.loginWithGoogle(idToken));

  Future<void> logout() async {
    final refresh = _tokens.refreshToken;
    await _tokens.clear();
    state = const AuthState.unauthenticated(signedOutByUser: true);
    await ref.read(googleSignInServiceProvider).signOut();
    if (refresh != null) {
      try {
        await _authApi.logout(refresh);
      } on DioException {
        // Already signed out locally; the token expires on its own.
      }
    }
  }

  /// Re-reads the user from the server (e.g. after confirming the email).
  Future<void> reloadUser() async {
    if (!state.isAuthenticated) return;
    setUser(await ref.read(userApiProvider).me());
  }

  void setUser(User user) {
    if (state.isAuthenticated) state = AuthState.authenticated(user);
  }

  /// After a password change the server issues new tokens and revokes the old ones.
  Future<void> replaceSession(AuthSession session) => _applySession(session);

  Future<void> deleteAccount({String? password}) async {
    await ref.read(userApiProvider).deleteAccount(password: password);
    await _tokens.clear();
    state = const AuthState.unauthenticated(signedOutByUser: true);
    await ref.read(googleSignInServiceProvider).signOut();
  }

  // Called by the HTTP interceptor.
  void onSessionRefreshed(AuthSession session) => setUser(session.user);

  Future<void> onSessionExpired() async {
    await _tokens.clear();
    state = const AuthState.unauthenticated();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
