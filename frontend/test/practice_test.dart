import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_adviser/features/auth/domain/auth_state.dart';

import 'copilot_test.dart' show openCopilot;
import 'helpers.dart';
import 'market_test.dart' show openAsset;

void go(WidgetTester tester, String location) =>
    GoRouterHelper(tester.element(find.byType(Scaffold).last)).go(location);

Future<void> openPractice(WidgetTester tester, FakePracticeApi api) async {
  tester.view.physicalSize = const Size(900, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpApp(tester, AuthState.authenticated(testUser()), practice: api);
  await tester.tap(find.byTooltip('Practice'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('practice account: value, holdings, waiting orders, history', (
    tester,
  ) async {
    final api = FakePracticeApi(
      account: testPracticeAccount(
        holding: true,
        pending: [testOrderJson(id: 7, status: 'pending')],
      ),
      orders: [
        testOrderJson(id: 7, status: 'pending'),
        testOrderJson(id: 6, side: 'sell', filledQuantity: 1, gainUsd: 50),
        testOrderJson(id: 5, status: 'cancelled'),
      ],
    );
    await openPractice(tester, api);

    expect(find.text(r'$10,100.00'), findsOneWidget);
    expect(find.textContaining(r'+$100.00 (+1.00%)'), findsOneWidget);
    expect(find.text('Apple Inc.'), findsOneWidget);
    expect(find.textContaining(r'2 AAPL · bought at $250.00'), findsOneWidget);
    expect(find.textContaining(r'+$100.00 (+20.00%)'), findsOneWidget);
    expect(find.text(r'Buy $500.00 of AAPL'), findsOneWidget); // waiting
    expect(find.text('Sold 1 AAPL'), findsOneWidget);
    expect(find.text(r'Locked in +$50.00'), findsOneWidget);
    expect(find.text(r'Cancelled: Buy $500.00 of AAPL'), findsOneWidget);

    await tester.tap(find.text('Cancel order'));
    await tester.pumpAndSettle();
    expect(api.cancelled, [7]);
    expect(find.text('Order cancelled.'), findsOneWidget);

    // Every number explains itself.
    await tester.tap(find.text('Total value'));
    await tester.pumpAndSettle();
    expect(find.textContaining(r'You started with $10,000.00'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start over').last);
    await tester.pumpAndSettle();
    expect(find.text(r'Start over with $10,000.00?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Start over'));
    await tester.pumpAndSettle();
    expect(api.resets, 1);
    expect(
      find.textContaining("You haven't bought anything yet"),
      findsOneWidget,
    );
  });

  testWidgets('practice buy from the asset page, in dollars', (tester) async {
    final api = FakePracticeApi();
    await openAsset(tester, practice: api);
    go(tester, '/assets/1');
    await tester.pumpAndSettle();

    expect(
      find.text('Try it with virtual money and see how it would have gone.'),
      findsOneWidget,
    );
    expect(find.text('Practice sell'), findsNothing); // nothing held
    await tester.ensureVisible(find.text('Practice buy'));
    await tester.tap(find.text('Practice buy'));
    await tester.pumpAndSettle();
    expect(find.text(r'Price now: $250.00'), findsOneWidget);
    expect(find.text(r'Practice cash available: $10,000.00'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '20000');
    await tester.pump();
    await tester.tap(find.text('Buy with practice money'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining("That's more than your practice cash"),
      findsOneWidget,
    );
    expect(api.placed, isEmpty);

    await tester.enterText(find.byType(TextField), '500');
    await tester.pump();
    expect(find.text('≈ 2 2222.SR'), findsOneWidget);
    await tester.tap(find.text('Buy with practice money'));
    await tester.pumpAndSettle();
    expect(api.placed.single, {
      'asset_id': 1,
      'side': 'buy',
      'quantity': null,
      'amount_usd': 500.0,
    });
    expect(
      find.text(r'Bought 2 2222.SR for $500.00 (practice).'),
      findsOneWidget,
    );
  });

  testWidgets('closed market: the order waits; sell all uses every unit', (
    tester,
  ) async {
    final api = FakePracticeApi(
      account: testPracticeAccount(holding: true),
      marketOpen: false,
      held: 2.5,
    );
    await openAsset(tester, practice: api);
    go(tester, '/assets/1');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Practice sell'));
    await tester.tap(find.text('Practice sell'));
    await tester.pumpAndSettle();
    expect(find.textContaining('The market is closed'), findsOneWidget);
    expect(find.text('You have 2.5 2222.SR'), findsOneWidget);

    await tester.tap(find.text('Sell all'));
    await tester.pump();
    await tester.tap(find.text('Sell (practice)'));
    await tester.pumpAndSettle();
    expect(api.placed.single['quantity'], 2.5);
    expect(
      find.text('Order placed. It will fill when the market opens.'),
      findsOneWidget,
    );
  });

  testWidgets('copilot practice trades show an undoable card', (tester) async {
    await openCopilot(tester, [
      [
        {'event': 'conversation', 'conversation_id': 5, 'title': 'Buy'},
        {
          'event': 'action',
          'card': {
            'type': 'practice_order',
            'order_id': 42,
            'asset_id': 1,
            'symbol': 'AAPL',
            'name': 'Apple Inc.',
            'side': 'buy',
            'status': 'filled',
            'quantity': 2,
            'amount_usd': 500,
            'total_usd': 500,
            'note': null,
          },
        },
        {
          'event': 'done',
          'message_id': 1,
          'text': 'Bought 2 AAPL in your practice account.',
          'actions': <Map<String, dynamic>>[],
          'remaining_today': 29,
        },
      ],
    ]);
    await tester.enterText(find.byType(TextField), r'Buy $500 of Apple');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(find.text(r'Practice: bought 2 AAPL for $500.00'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Undone'), findsOneWidget);
  });
}
