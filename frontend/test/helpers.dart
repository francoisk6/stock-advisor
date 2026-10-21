import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_adviser/app.dart';
import 'package:stock_adviser/features/auth/application/auth_controller.dart';
import 'package:stock_adviser/features/auth/domain/auth_state.dart';
import 'package:stock_adviser/features/auth/domain/user.dart';
import 'package:stock_adviser/features/brief/data/brief_api.dart';
import 'package:stock_adviser/features/health/data/health_repository.dart';
import 'package:stock_adviser/features/learn/data/learn_api.dart';
import 'package:stock_adviser/features/learn/domain/glossary_term.dart';
import 'package:stock_adviser/features/learn/domain/lesson.dart';
import 'package:stock_adviser/features/market/data/market_api.dart';
import 'package:stock_adviser/features/market/domain/market.dart';
import 'package:stock_adviser/features/notifications/data/notifications_api.dart';
import 'package:stock_adviser/features/notifications/domain/app_notification.dart';
import 'package:stock_adviser/features/plans/data/plans_api.dart';
import 'package:stock_adviser/features/plans/domain/plans.dart';
import 'package:stock_adviser/features/portfolio/data/portfolio_api.dart';
import 'package:stock_adviser/features/portfolio/domain/portfolio.dart';
import 'package:stock_adviser/features/practice/data/practice_api.dart';
import 'package:stock_adviser/features/practice/domain/practice.dart';
import 'package:stock_adviser/features/watchlist/data/watchlist_api.dart';

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

class FakeWatchlistController extends WatchlistController {
  FakeWatchlistController(this.items);

  final List<Asset> items;

  @override
  Future<Watchlist> build() async =>
      Watchlist(name: 'My watchlist', limit: 25, items: items);

  @override
  Future<void> add(int assetId) async => state = AsyncData(
    Watchlist(
      name: 'My watchlist',
      limit: 25,
      items: [
        ...items,
        testAsset(id: assetId),
      ],
    ),
  );

  @override
  Future<void> remove(int assetId) async => state = AsyncData(
    Watchlist(
      name: 'My watchlist',
      limit: 25,
      items: items.where((a) => a.id != assetId).toList(),
    ),
  );
}

class FakeBriefController extends BriefController {
  FakeBriefController(this.brief);

  final Brief? brief;

  @override
  Future<Brief?> build() async => brief;

  @override
  Future<void> create() async => state = AsyncData(
    Brief(
      content:
          '## Your markets\n- Bitcoin is up 10%.\n## In the news\n'
          '- According to [Reuters](https://example.com/r), ETF demand rose.',
      createdAt: DateTime.utc(2026, 10, 17, 3),
    ),
  );
}

class FakeNotificationsController extends NotificationsController {
  FakeNotificationsController(this.inbox);

  final NotificationInbox inbox;

  @override
  Future<NotificationInbox> build() async => inbox;
}

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
  List<Asset> watchlist = const [],
  NotificationInbox inbox = const NotificationInbox(unreadCount: 0, items: []),
  Brief? brief,
  FakePracticeApi? practice,
  FakePortfolioApi? portfolio,
  FakeLearnApi? learn,
  FakePlansApi? plans,
  WatchlistController Function()? watchlistController,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null, // no background retries (pending timers) in tests
      overrides: [
        watchlistProvider.overrideWith(
          watchlistController ?? () => FakeWatchlistController(watchlist),
        ),
        briefProvider.overrideWith(() => FakeBriefController(brief)),
        notificationsProvider.overrideWith(
          () => FakeNotificationsController(inbox),
        ),
        authControllerProvider.overrideWith(() => FakeAuthController(auth)),
        healthStatusProvider.overrideWith(
          (ref) async => const HealthStatus(status: 'ok', environment: 'test'),
        ),
        // The home screen's market list, without network.
        glossaryProvider.overrideWith((ref) async => testGlossary),
        learnApiProvider.overrideWithValue(learn ?? FakeLearnApi()),
        plansApiProvider.overrideWithValue(plans ?? FakePlansApi()),
        practiceApiProvider.overrideWithValue(practice ?? FakePracticeApi()),
        portfolioApiProvider.overrideWithValue(portfolio ?? FakePortfolioApi()),
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

GlossaryTerm _term(
  String id,
  String term,
  String category, {
  List<String> aliases = const [],
  String? example,
  List<String> related = const [],
}) => GlossaryTerm(
  id: id,
  term: term,
  aliases: aliases,
  category: category,
  short: 'Short: $term.',
  body: 'Body of $term.',
  example: example,
  related: related,
);

final testGlossary = [
  _term('etf', 'ETF (exchange-traded fund)', 'funds', aliases: ['index fund']),
  _term('eps', 'Earnings per share (EPS)', 'valuation', related: ['pe-ratio']),
  _term(
    'pe-ratio',
    'P/E ratio',
    'valuation',
    aliases: ['price to earnings'],
    example: 'A \$60 share with \$3 EPS has a P/E of 20.',
    related: ['eps', 'missing-id'],
  ),
  _term('stablecoin', 'Stablecoin', 'crypto'),
  _term('volatility', 'Volatility', 'risk'),
];

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

/// In-memory secure storage for tests.
class FakeSecureStorage implements FlutterSecureStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

Map<String, dynamic> _assetJson(Asset a) => {
  'id': a.id,
  'symbol': a.symbol,
  'name': a.name,
  'asset_type': a.assetType,
  'exchange': a.exchange,
  'country': null,
  'region': a.region,
  'currency': a.currency,
  'logo_url': null,
};

Map<String, dynamic> testOrderJson({
  int id = 1,
  Asset? asset,
  String side = 'buy',
  String status = 'filled',
  double? quantity,
  double? amountUsd = 500,
  double filledQuantity = 2,
  double price = 250,
  double? gainUsd,
}) => {
  'id': id,
  'asset': _assetJson(asset ?? testAsset(symbol: 'AAPL', name: 'Apple Inc.')),
  'side': side,
  'quantity': quantity,
  'amount_usd': amountUsd,
  'status': status,
  'source': 'app',
  'created_at': '2026-10-18T10:00:00',
  'filled_at': status == 'filled' ? '2026-10-18T10:00:00' : null,
  'filled_quantity': status == 'filled' ? filledQuantity : null,
  'price': status == 'filled' ? price : null,
  'currency': status == 'filled' ? 'USD' : null,
  'fx_rate': status == 'filled' ? 1.0 : null,
  'total_usd': status == 'filled' ? filledQuantity * price : null,
  'gain_usd': gainUsd,
  'reserved_usd': status == 'pending' ? 500.0 : 0.0,
  'note': status == 'rejected' ? 'Not enough practice cash.' : null,
};

PracticeAccount testPracticeAccount({
  bool holding = false,
  List<Map<String, dynamic>> pending = const [],
}) {
  final apple = testAsset(symbol: 'AAPL', name: 'Apple Inc.', currency: 'USD');
  return PracticeAccount.fromJson({
    'starting_cash': 10000.0,
    'cash': holding ? 9500.0 : 10000.0,
    'reserved_usd': 0.0,
    'available_cash': holding ? 9500.0 : 10000.0,
    'positions_value': holding ? 600.0 : 0.0,
    'total_value': holding ? 10100.0 : 10000.0,
    'gain_usd': holding ? 100.0 : 0.0,
    'gain_percent': holding ? 1.0 : 0.0,
    'realized_usd': 0.0,
    'started_at': '2026-10-18T09:00:00',
    'prices_complete': true,
    'positions': [
      if (holding)
        {
          'asset': _assetJson(apple),
          'quantity': 2.0,
          'average_price': 250.0,
          'currency': 'USD',
          'price': 300.0,
          'change_percent': 1.0,
          'usd_rate': 1.0,
          'as_of': '2026-10-18T10:00:00',
          'cost_usd': 500.0,
          'value_usd': 600.0,
          'gain_usd': 100.0,
          'gain_percent': 20.0,
          'share_percent': 5.94,
        },
    ],
    'pending': pending,
  });
}

/// Practice API stand-in: a fixed account and quote; records what the app asked for.
class FakePracticeApi implements PracticeApi {
  FakePracticeApi({
    PracticeAccount? account,
    this.orders = const [],
    this.marketOpen = true,
    this.held = 0,
  }) : state = account ?? testPracticeAccount();

  PracticeAccount state;
  List<Map<String, dynamic>> orders;
  bool marketOpen;
  double held;
  final placed = <Map<String, Object?>>[];
  final cancelled = <int>[];
  final undone = <int>[];
  int resets = 0;

  @override
  Future<PracticeAccount> account() async => state;

  @override
  Future<PracticeAccount> reset() async {
    resets++;
    return state = testPracticeAccount();
  }

  @override
  Future<PracticeQuote> quote(int assetId) async => PracticeQuote(
    price: 250,
    currency: 'USD',
    usdPrice: 250,
    marketOpen: marketOpen,
    heldQuantity: held,
    availableCash: state.availableCash,
  );

  @override
  Future<PracticeOrder> order({
    required int assetId,
    required String side,
    double? quantity,
    double? amountUsd,
  }) async {
    placed.add({
      'asset_id': assetId,
      'side': side,
      'quantity': quantity,
      'amount_usd': amountUsd,
    });
    return PracticeOrder.fromJson(
      testOrderJson(
        side: side,
        status: marketOpen ? 'filled' : 'pending',
        quantity: quantity,
        amountUsd: amountUsd,
        filledQuantity: quantity ?? (amountUsd! / 250),
      ),
    );
  }

  @override
  Future<List<PracticeOrder>> history() async => [
    for (final o in orders) PracticeOrder.fromJson(o),
  ];

  @override
  Future<void> cancel(int orderId) async => cancelled.add(orderId);

  @override
  Future<void> undo(int orderId) async => undone.add(orderId);
}

Map<String, dynamic> testHoldingJson({
  int id = 1,
  Asset? asset,
  double quantity = 10,
  double averagePrice = 150,
  double value = 2000,
  double gain = 500,
  double share = 72.07,
}) => {
  'id': id,
  'asset': _assetJson(
    asset ?? testAsset(symbol: 'AAPL', name: 'Apple Inc.', currency: 'USD'),
  ),
  'quantity': quantity,
  'average_price': averagePrice,
  'currency': 'USD',
  'bought_on': null,
  'note': null,
  'price': 200.0,
  'change_percent': 1.0,
  'value': value,
  'cost': value - gain,
  'gain': gain,
  'gain_percent': gain / (value - gain) * 100,
  'share_percent': share,
};

Portfolio testPortfolio({bool empty = false, String currency = 'USD'}) =>
    Portfolio.fromJson({
      'currency': currency,
      'total_value': empty ? 0.0 : 2775.0,
      'total_cost': empty ? 0.0 : 2100.0,
      'gain': empty ? 0.0 : 675.0,
      'gain_percent': empty ? null : 32.14,
      'day_change': empty ? 0.0 : 25.0,
      'prices_complete': true,
      'holdings': empty
          ? <Map<String, dynamic>>[]
          : [
              testHoldingJson(),
              testHoldingJson(
                id: 2,
                asset: testAsset(
                  id: 2,
                  symbol: 'BTC',
                  name: 'Bitcoin',
                  type: 'crypto',
                  currency: 'USD',
                ),
                quantity: 0.01,
                averagePrice: 60000,
                value: 775,
                gain: 175,
                share: 27.93,
              ),
            ],
      'by_type': empty
          ? []
          : [
              {'key': 'stock', 'value': 2000.0, 'percent': 72.07},
              {'key': 'crypto', 'value': 775.0, 'percent': 27.93},
            ],
      'by_region': empty
          ? []
          : [
              {'key': 'north_america', 'value': 2000.0, 'percent': 72.07},
              {'key': 'global', 'value': 775.0, 'percent': 27.93},
            ],
      'by_currency': empty
          ? []
          : [
              {'key': 'USD', 'value': 2775.0, 'percent': 100.0},
            ],
      'risks': empty
          ? []
          : [
              {
                'code': 'concentration',
                'level': 'caution',
                'params': {
                  'symbol': 'AAPL',
                  'percent': 72.1,
                  'drop_if_30': 21.6,
                },
              },
              {
                'code': 'crypto_share',
                'level': 'caution',
                'params': {'percent': 27.9},
              },
            ],
    });

/// Portfolio API stand-in: a fixed portfolio; records adds, edits, removals.
class FakePortfolioApi implements PortfolioApi {
  FakePortfolioApi({Portfolio? portfolio})
    : state = portfolio ?? testPortfolio(empty: true);

  Portfolio state;
  final added = <Map<String, Object?>>[];
  final edited = <Map<String, Object?>>[];
  final removed = <int>[];
  final currencies = <String>[];

  @override
  Future<Portfolio> get() async => state;

  @override
  Future<Portfolio> add({
    required int assetId,
    required double quantity,
    required double averagePrice,
    DateTime? boughtOn,
    String? note,
  }) async {
    added.add({
      'asset_id': assetId,
      'quantity': quantity,
      'average_price': averagePrice,
    });
    return state = testPortfolio();
  }

  @override
  Future<Portfolio> update(
    int holdingId, {
    required double quantity,
    required double averagePrice,
    DateTime? boughtOn,
    String? note,
  }) async {
    edited.add({
      'id': holdingId,
      'quantity': quantity,
      'average_price': averagePrice,
    });
    return state;
  }

  @override
  Future<void> delete(int holdingId) async => removed.add(holdingId);

  @override
  Future<Portfolio> setCurrency(String currency) async {
    currencies.add(currency);
    return state = testPortfolio(currency: currency);
  }
}

Map<String, dynamic> testLessonJson({
  String id = 'risk-basics',
  String title = 'Risk basics',
  bool suggested = true,
  bool done = false,
}) => {
  'id': id,
  'title': title,
  'minutes': 4,
  'level': 'beginner',
  'summary': 'Summary of $title.',
  'suggested': suggested,
  'done': done,
  'best_score': done ? 2 : null,
  'total': 2,
  'sections': [
    {'heading': 'Ups and downs', 'body': 'Prices **swing**.'},
  ],
  'terms': ['volatility', 'etf'],
  'quiz': [
    {
      'question': 'A fall of 50% needs a rise of…',
      'options': ['50%', '100%'],
    },
    {
      'question': 'Diversification…',
      'options': ['removes all risk', 'lowers risk'],
    },
  ],
};

/// Lessons stand-in (the glossary itself comes from [testGlossary]).
class FakeLearnApi implements LearnApi {
  final submitted = <List<int>>[];

  @override
  Future<List<GlossaryTerm>> glossary() async => testGlossary;

  @override
  Future<List<LessonSummary>> lessons() async => [
    LessonSummary.fromJson(testLessonJson()),
    LessonSummary.fromJson(
      testLessonJson(
        id: 'charts',
        title: 'Reading charts',
        suggested: false,
        done: true,
      ),
    ),
  ];

  @override
  Future<Lesson> lesson(String id) async =>
      Lesson.fromJson(testLessonJson(id: id));

  @override
  Future<QuizResult> submitQuiz(String id, List<int> answers) async {
    submitted.add(answers);
    final right = [1, 1];
    return QuizResult.fromJson({
      'score': [
        for (final (i, a) in answers.indexed)
          if (a == right[i]) 1,
      ].length,
      'total': 2,
      'best_score': 2,
      'results': [
        for (final (i, a) in answers.indexed)
          {
            'correct': a == right[i],
            'answer': right[i],
            'explanation': 'Because $i.',
          },
      ],
    });
  }
}

/// Plans stand-in: Free (3 watchlist, 5 questions) and Pro (unlimited, not for sale yet).
class FakePlansApi implements PlansApi {
  bool interested = false;
  int interestCalls = 0;

  @override
  Future<List<PlanInfo>> plans() async => [
    PlanInfo.fromJson({
      'code': 'free',
      'name': 'Free',
      'price_monthly_usd': 0,
      'price_yearly_usd': 0,
      'for_sale': true,
      'limits': {'ai_messages_per_day': 5, 'watchlist_assets': 3},
    }),
    PlanInfo.fromJson({
      'code': 'pro',
      'name': 'Pro',
      'price_monthly_usd': 4.99,
      'price_yearly_usd': 39.99,
      'for_sale': false,
      'limits': {'ai_messages_per_day': null, 'watchlist_assets': null},
    }),
  ];

  @override
  Future<PlanUsage> usage() async => PlanUsage.fromJson({
    'plan': 'free',
    'plan_name': 'Free',
    'items': [
      {'key': 'ai_messages_per_day', 'used': 2, 'limit': 5},
      {'key': 'watchlist_assets', 'used': 3, 'limit': 3},
    ],
    'pro_interest_at': interested ? '2026-10-21T10:00:00' : null,
  });

  @override
  Future<PlanUsage> proInterest() async {
    interestCalls++;
    interested = true;
    return usage();
  }
}
