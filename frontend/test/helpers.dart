import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_adviser/app.dart';
import 'package:stock_adviser/features/auth/application/auth_controller.dart';
import 'package:stock_adviser/features/auth/domain/auth_state.dart';
import 'package:stock_adviser/features/auth/domain/user.dart';
import 'package:stock_adviser/features/health/data/health_repository.dart';
import 'package:stock_adviser/features/market/data/market_api.dart';
import 'package:stock_adviser/features/market/domain/market.dart';

User testUser({
  bool onboarded = true,
  bool verified = true,
  String name = 'Ana Lopez',
  List<String> interests = const ['stocks'],
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
    'asset_interests': onboarded ? interests : <String>[],
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
  List<Asset> popular = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => FakeAuthController(auth)),
        healthStatusProvider.overrideWith(
          (ref) async => const HealthStatus(status: 'ok', environment: 'test'),
        ),
        // The home screen's market list, without network.
        popularAssetsProvider.overrideWith(
          (ref, type) async => [
            for (final a in popular)
              if (type == null || a.assetType == type) a,
          ],
        ),
        ...overrides,
      ],
      child: const StockAdviserApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Asset testAsset({
  int id = 1,
  String symbol = '2222.SR',
  String name = 'Saudi Arabian Oil Company',
  String type = 'stock',
  double? price = 25.78,
  double? changePercent = 1.5,
  String currency = 'SAR',
}) => Asset.fromJson({
  'id': id,
  'symbol': symbol,
  'name': name,
  'asset_type': type,
  'exchange': 'Tadawul',
  'country': 'SA',
  'region': 'middle_east',
  'currency': currency,
  'logo_url': null,
  'quote': price == null
      ? null
      : {
          'price': price,
          'change': 0.38,
          'change_percent': changePercent,
          'previous_close': 25.4,
          'currency': currency,
          'as_of': '2026-10-13T12:00:00',
          'market_open': true,
        },
});
