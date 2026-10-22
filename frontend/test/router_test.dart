import 'package:flutter_test/flutter_test.dart';
import 'package:stock_adviser/core/router/app_router.dart';
import 'package:stock_adviser/features/auth/domain/auth_state.dart';

import 'helpers.dart';

void main() {
  final signedOut = const AuthState.unauthenticated();
  final newUser = AuthState.authenticated(testUser(onboarded: false));
  final member = AuthState.authenticated(testUser());

  String? go(AuthState s, String location) =>
      authRedirect(s, Uri.parse(location));

  test('waits on splash while the session is restored', () {
    expect(
      go(const AuthState.unknown(), '/profile'),
      '/splash?from=%2Fprofile',
    );
    expect(go(const AuthState.unknown(), '/splash'), isNull);
  });

  test('signed-out users go to login, remembering where they were going', () {
    expect(go(signedOut, '/'), '/login');
    expect(go(signedOut, '/profile'), '/login?from=%2Fprofile');
    expect(go(signedOut, '/register'), isNull);
    expect(go(signedOut, '/forgot-password'), isNull);
  });

  test('signing out on purpose does not return to the previous page', () {
    const left = AuthState.unauthenticated(signedOutByUser: true);
    expect(go(left, '/profile'), '/login');
  });

  test('email links open whether signed in or not', () {
    for (final state in [signedOut, newUser, member]) {
      expect(go(state, '/verify-email?token=abc'), isNull);
      expect(go(state, '/reset-password?token=abc'), isNull);
      expect(go(state, '/legal/privacy'), isNull);
      expect(go(state, '/legal/terms'), isNull);
    }
  });

  test('new users must finish onboarding first', () {
    expect(go(newUser, '/'), '/onboarding');
    expect(go(newUser, '/profile'), '/onboarding');
    expect(go(newUser, '/onboarding'), isNull);
  });

  test(
    'signed-in users skip guest pages and return to where they were going',
    () {
      expect(go(member, '/login'), '/');
      expect(go(member, '/login?from=%2Fprofile'), '/profile');
      expect(go(member, '/splash?from=%2Fprofile'), '/profile');
      expect(go(member, '/login?from=https%3A%2F%2Fevil.example'), '/');
      expect(go(member, '/login?from=%2F%2Fevil.example'), '/');
      expect(go(member, '/profile'), isNull);
    },
  );
}
