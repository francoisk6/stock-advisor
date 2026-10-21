import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_adviser/features/auth/domain/auth_state.dart';
import 'package:stock_adviser/features/market/data/market_api.dart';

import 'helpers.dart';
import 'market_test.dart' show FakeMarketApi, openAsset;

void go(WidgetTester tester, String location) =>
    GoRouterHelper(tester.element(find.byType(Scaffold).last)).go(location);

Future<FakePortfolioApi> openPortfolio(
  WidgetTester tester,
  FakePortfolioApi api,
) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpApp(
    tester,
    AuthState.authenticated(testUser()),
    portfolio: api,
    overrides: [marketApiProvider.overrideWithValue(FakeMarketApi())],
  );
  await tester.tap(find.byTooltip('Portfolio'));
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('portfolio: value, risks in plain words, allocation, holdings', (
    tester,
  ) async {
    final api = await openPortfolio(
      tester,
      FakePortfolioApi(portfolio: testPortfolio()),
    );

    expect(find.text(r'$2,775.00'), findsOneWidget);
    expect(find.textContaining(r'+$675.00 (+32.14%)'), findsOneWidget);
    expect(find.text(r'Today: +$25.00'), findsOneWidget);
    expect(
      find.text(
        'AAPL is 72.10% of your portfolio. If it fell 30%, your whole '
        'portfolio would fall about 21.60%.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('27.90% is in crypto'), findsOneWidget);
    expect(find.textContaining('not advice'), findsOneWidget);

    // Allocation by type, then by region.
    expect(find.text('Stock'), findsOneWidget);
    expect(find.text(r'72.07% · $2,000.00'), findsWidgets);
    await tester.tap(find.text('Region'));
    await tester.pumpAndSettle();
    expect(find.text('North America'), findsOneWidget);

    expect(
      find.textContaining(r'10 AAPL · paid $150.00 on average'),
      findsOneWidget,
    );

    // Edit a holding.
    await tester.tap(find.text('Apple Inc.'));
    await tester.pumpAndSettle();
    expect(find.text('Edit AAPL'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Units you own'),
      '12',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(api.edited.single, {
      'id': 1,
      'quantity': 12.0,
      'average_price': 150.0,
    });
    expect(find.text('Saved to your portfolio.'), findsOneWidget);

    // Values in another currency.
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAR').last);
    await tester.pumpAndSettle();
    expect(api.currencies, ['SAR']);
    expect(find.text('SAR 2,775.00'), findsOneWidget);
  });

  testWidgets('empty portfolio: add a holding through search', (tester) async {
    final api = await openPortfolio(tester, FakePortfolioApi());
    expect(
      find.textContaining('Add the stocks, funds or coins you own'),
      findsOneWidget,
    );

    await tester.tap(find.text('Add a holding'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'aramco');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saudi Arabian Oil Company'));
    await tester.pumpAndSettle();

    expect(find.text('Add 2222.SR to your portfolio'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter how many units you own.'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Units you own'),
      '100',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Average price paid (SAR)'),
      '24.5',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(api.added.single, {
      'asset_id': 1,
      'quantity': 100.0,
      'average_price': 24.5,
    });
    expect(find.text(r'$2,775.00'), findsOneWidget); // the new summary
  });

  testWidgets('asset page offers "Add to my portfolio"', (tester) async {
    await openAsset(tester);
    go(tester, '/assets/1');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add to my portfolio'));
    await tester.tap(find.text('Add to my portfolio'));
    await tester.pumpAndSettle();
    expect(find.text('Add 2222.SR to your portfolio'), findsOneWidget);
    // Today's price is filled in to start.
    expect(find.widgetWithText(TextField, '25.78'), findsOneWidget);
  });
}
