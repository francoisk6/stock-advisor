import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_adviser/core/format/numbers.dart';
import 'package:stock_adviser/features/auth/domain/auth_state.dart';
import 'package:stock_adviser/features/market/data/market_api.dart';
import 'package:stock_adviser/features/market/domain/market.dart';

import 'helpers.dart';

class FakeMarketApi implements MarketApi {
  FakeMarketApi({this.changePercent = 1.5});

  final double changePercent;
  final historyRequests = <String>[];
  final searches = <String>[];

  @override
  Future<AssetDetail> detail(int id) async => AssetDetail.fromJson({
    ...{
      'id': id,
      'symbol': '2222.SR',
      'name': 'Saudi Arabian Oil Company',
      'asset_type': 'stock',
      'exchange': 'Tadawul',
      'country': 'SA',
      'region': 'middle_east',
      'currency': 'SAR',
      'logo_url': null,
    },
    'quote': {
      'price': 25.78,
      'change': 0.38,
      'change_percent': changePercent,
      'previous_close': 25.4,
      'currency': 'SAR',
      'as_of': '2026-10-13T12:00:00',
      'market_open': false,
    },
    'stats': [
      {'key': 'market_cap', 'value': 6.2e12, 'unit': 'compact'},
      {'key': 'pe_ratio', 'value': 15.25, 'unit': 'number'},
      {'key': 'week52_low', 'value': 23.1, 'unit': 'money'},
      {'key': 'week52_high', 'value': 28.4, 'unit': 'money'},
      {'key': 'sector', 'value': 'Energy', 'unit': 'text'},
    ],
    'description': 'Saudi Aramco explores, produces and sells oil.',
    'ranges': ['1D', '1W', '1M', '6M', '1Y', '5Y'],
    'data_source': 'Yahoo Finance',
  });

  @override
  Future<PriceHistory> history(int id, String range) async {
    historyRequests.add(range);
    return PriceHistory.fromJson({
      'range': range,
      'currency': 'SAR',
      'candles': [
        for (var i = 0; i < 10; i++)
          {
            't': '2026-10-0${i % 9 + 1}T08:00:00',
            'o': 25.0 + i * 0.1,
            'h': 25.3 + i * 0.1,
            'l': 24.9 + i * 0.1,
            'c': 25.1 + i * 0.1,
            'v': 1000,
          },
      ],
    });
  }

  @override
  Future<List<Asset>> search(String query) async {
    searches.add(query);
    return query.toLowerCase().startsWith('aram') ? [testAsset()] : [];
  }

  @override
  Future<List<Asset>> popular({String? type}) async => [];

  @override
  Future<String> whyMoved(int id) async =>
      'Aramco rose after results, according to [Reuters](https://example.com/r).';

  @override
  Future<List<NewsHeadline>> news(int id) async => [
    NewsHeadline(
      title: 'Aramco profit rises',
      url: 'https://example.com/aramco',
      source: 'Reuters',
      publishedAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
    ),
  ];
}

Future<FakeMarketApi> openAsset(
  WidgetTester tester, {
  double changePercent = 1.5,
  FakePracticeApi? practice,
}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = FakeMarketApi(changePercent: changePercent);
  await pumpApp(
    tester,
    AuthState.authenticated(testUser()),
    overrides: [marketApiProvider.overrideWithValue(api)],
    practice: practice,
  );
  return api;
}

void main() {
  test('number formatting for beginners', () {
    expect(formatPercent(1.234), '+1.23%');
    expect(formatPercent(-0.5), '-0.50%');
    expect(formatPrice(83338, 'USD'), r'$83,338.00');
    expect(formatPrice(0.0812, 'USD'), r'$0.0812');
    expect(formatPrice(1.12013, 'USD', forex: true), r'$1.1201');
    expect(formatCompactMoney(4.98e12, 'USD'), r'$4.98T');
    expect(formatPrice(25.78, 'SAR'), 'SAR\u00A025.78');
    expect(formatCompactMoney(6.2e12, 'SAR'), 'SAR\u00A06.2T');
  });

  testWidgets('asset page shows price, chart, explained key figures', (
    tester,
  ) async {
    final api = await openAsset(tester);
    final context = tester.element(find.byType(Scaffold).first);
    GoRouterHelper(context).go('/assets/1');
    await tester.pumpAndSettle();

    expect(find.text('Saudi Arabian Oil Company'), findsOneWidget);
    expect(find.text('Market closed'), findsOneWidget);
    expect(find.text('+1.50%'), findsOneWidget);
    expect(api.historyRequests, ['1M']); // default range
    expect(find.textContaining('over the past month'), findsOneWidget);

    // Key figures: low/high merged into one range row, values formatted.
    expect(find.text('Market cap'), findsOneWidget);
    expect(find.text('P/E ratio'), findsOneWidget);
    expect(find.text('52-week range'), findsOneWidget);
    expect(find.text('Energy'), findsOneWidget);

    await tester.tap(find.text('P/E ratio'));
    await tester.pumpAndSettle();
    expect(find.textContaining('how many years of'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, '1Y'));
    await tester.pumpAndSettle();
    expect(api.historyRequests, ['1M', '1Y']);
    expect(find.textContaining('over the past year'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.candlestick_chart_outlined));
    await tester.pumpAndSettle();
    expect(find.textContaining('Each candle shows one period'), findsOneWidget);
    expect(find.textContaining('Data: Yahoo Finance'), findsOneWidget);
    expect(find.text('Aramco profit rises'), findsOneWidget);
    expect(
      find.textContaining('Why is'),
      findsNothing,
    ); // +1.5% is a normal day
    expect(find.text('Reuters · 2 hours ago'), findsOneWidget);
  });

  testWidgets('search waits for typing to pause, then lists results', (
    tester,
  ) async {
    final api = await openAsset(tester);
    await tester.tap(find.byType(SearchBar));
    await tester.pumpAndSettle();
    expect(find.textContaining('Try a company name'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ar');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'aramco');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(api.searches, ['aramco']); // one request, not one per keystroke
    expect(find.text('Saudi Arabian Oil Company'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.textContaining('No results for “zzzz”'), findsOneWidget);
  });

  testWidgets('big moves offer a "why did it move?" explanation', (
    tester,
  ) async {
    await openAsset(tester, changePercent: 3.2);
    final context = tester.element(find.byType(Scaffold).first);
    GoRouterHelper(context).go('/assets/1');
    await tester.pumpAndSettle();

    expect(find.text('Why is 2222.SR up 3.20% today?'), findsOneWidget);
    await tester.tap(find.text('Explain'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Aramco rose after results, according to Reuters.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('AI summary of recent headlines'),
      findsOneWidget,
    );
  });
}
