import 'user.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState {
  const AuthState._(this.status, this.user, {this.signedOutByUser = false});

  /// Restoring a saved session at startup.
  const AuthState.unknown() : this._(AuthStatus.unknown, null);

  /// [signedOutByUser]: the user chose to leave (sign out / delete account), as opposed to
  /// an expired session — so sign-in should not return them to the page they were on.
  const AuthState.unauthenticated({bool signedOutByUser = false})
    : this._(
        AuthStatus.unauthenticated,
        null,
        signedOutByUser: signedOutByUser,
      );

  const AuthState.authenticated(User user)
    : this._(AuthStatus.authenticated, user);

  final AuthStatus status;
  final User? user;
  final bool signedOutByUser;

  bool get isAuthenticated => status == AuthStatus.authenticated;
}
