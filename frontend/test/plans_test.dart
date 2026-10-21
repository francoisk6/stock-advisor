import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_adviser/features/auth/domain/auth_state.dart';
import 'package:stock_adviser/features/market/data/market_api.dart';

import 'copilot_test.dart' show openCopilot;
import 'helpers.dart';
import 'market_test.dart' show FakeMarketApi;

/// Watchlist that is full on the Free plan: adding fails like the API does.
class FullWatchlistController extends FakeWatchlistController {
  FullWatchlistController() : super(const []);

  @override
  Future<void> add(int assetId) async => throw DioException(
    requestOptions: RequestOptions(path: '/watchlist/assets/$assetId'),
    response: Response(
      requestOptions: RequestOptions(path: '/watchlist/assets/$assetId'),
      statusCode: 403,
      data: {
        'detail':
            'The Free plan allows up to 3 assets in your watchlist. Remove one to '
            'add another. Pro (coming soon) has no limit.',
        'code': 'plan_limit',
      },
    ),
  );
}

void main() {
  testWidgets('plans: usage, Free vs Pro, price, tell me when Pro is ready', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final plans = FakePlansApi();
    await pumpApp(tester, AuthState.authenticated(testUser()), plans: plans);
    await tester.tap(find.byTooltip('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Free plan'));
    await tester.pumpAndSettle();

    expect(find.text('Your plan: Free'), findsOneWidget);
    expect(find.text('2 of 5'), findsOneWidget); // copilot questions today
    expect(find.text('3 of 3'), findsOneWidget); // watchlist
    expect(find.text('5 a day'), findsOneWidget);
    expect(find.text('Up to 3'), findsOneWidget);
    expect(find.text('Unlimited'), findsNWidgets(2));
    expect(find.text(r'$4.99 a month, or $39.99 a year'), findsOneWidget);
    expect(find.text('Paying yearly saves 33%.'), findsOneWidget);
    expect(find.textContaining("can't be bought yet"), findsOneWidget);

    await tester.tap(find.text('Tell me when Pro is ready'));
    await tester.pumpAndSettle();
    expect(plans.interestCalls, 1);
    expect(find.text('Tell me when Pro is ready'), findsNothing);
    expect(
      find.text("Thanks! We'll let you know when Pro is ready."),
      findsWidgets,
    );
  });

  testWidgets('a full watchlist explains the limit and offers the plans', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      AuthState.authenticated(testUser()),
      overrides: [marketApiProvider.overrideWithValue(FakeMarketApi())],
      watchlistController: FullWatchlistController.new,
    );
    GoRouterHelper(tester.element(find.byType(Scaffold).first)).go('/assets/1');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add to watchlist'));
    await tester.pumpAndSettle();
    expect(find.text("You've reached a limit of your plan"), findsOneWidget);
    expect(
      find.textContaining('up to 3 assets in your watchlist'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'See plans'));
    await tester.pumpAndSettle();
    expect(find.text('Your plan: Free'), findsOneWidget);
  });

  testWidgets('copilot daily limit offers the plans', (tester) async {
    await openCopilot(tester, [
      [
        {
          'event': 'error',
          'code': 'plan_limit',
          'detail':
              "You've used all 5 copilot questions for today on the Free plan.",
        },
      ],
    ]);
    await tester.enterText(find.byType(TextField), 'one more?');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(
      find.textContaining("You've used all 5 copilot questions"),
      findsOneWidget,
    );
    await tester.tap(find.text('See plans'));
    await tester.pumpAndSettle();
    expect(find.text('Your plan: Free'), findsOneWidget);
  });
}
