import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_adviser/app.dart';
import 'package:stock_adviser/features/auth/application/auth_controller.dart';
import 'package:stock_adviser/features/auth/domain/auth_state.dart';
import 'package:stock_adviser/features/auth/domain/user.dart';
import 'package:stock_adviser/features/health/data/health_repository.dart';

User testUser({
  bool onboarded = true,
  bool verified = true,
  String name = 'Ana Lopez',
}) => User.fromJson({
  'id': 1,
  'email': 'ana@example.com',
  'full_name': name,
  'email_verified': verified,
  'has_password': true,
  'auth_providers': <String>[],
  'created_at': '2026-10-13T10:00:00',
  'profile': {
    'experience_level': onboarded ? 'beginner' : null,
    'risk_profile': onboarded ? 'balanced' : null,
    'investment_horizon': onboarded ? 'long' : null,
    'asset_interests': onboarded ? ['stocks'] : <String>[],
    'region_interests': onboarded ? ['global'] : <String>[],
    'preferred_language': 'en',
    'preferred_currency': 'USD',
    'onboarding_completed_at': onboarded ? '2026-10-13T10:05:00' : null,
  },
  'plan': {'code': 'free', 'name': 'Free', 'limits': <String, dynamic>{}},
});

/// Auth controller with a fixed starting state and no network/storage access.
class FakeAuthController extends AuthController {
  FakeAuthController(this._initial);

  final AuthState _initial;

  @override
  AuthState build() => _initial;
}

Future<void> pumpApp(
  WidgetTester tester,
  AuthState auth, {
  List overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => FakeAuthController(auth)),
        healthStatusProvider.overrideWith(
          (ref) async => const HealthStatus(status: 'ok', environment: 'test'),
        ),
        ...overrides,
      ],
      child: const StockAdviserApp(),
    ),
  );
  await tester.pumpAndSettle();
}
