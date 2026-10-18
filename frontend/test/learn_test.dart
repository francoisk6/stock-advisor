import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_adviser/features/auth/domain/auth_state.dart';
import 'package:stock_adviser/features/copilot/data/chat_api.dart';
import 'package:stock_adviser/features/live/live_controller.dart';

import 'copilot_test.dart' show FakeChatApi, FakeLiveController, openCopilot;
import 'helpers.dart';
import 'market_test.dart' show openAsset;

void go(WidgetTester tester, String location) =>
    GoRouterHelper(tester.element(find.byType(Scaffold).last)).go(location);

void main() {
  testWidgets('glossary: search, topics, term page and related terms', (
    tester,
  ) async {
    await pumpApp(tester, AuthState.authenticated(testUser()));
    await tester.tap(find.byTooltip('Learn'));
    await tester.pumpAndSettle();
    expect(find.text('P/E ratio'), findsOneWidget);
    expect(find.text('Stablecoin'), findsOneWidget);

    // Search covers aliases too.
    await tester.enterText(find.byType(TextField), 'index fund');
    await tester.pumpAndSettle();
    expect(find.text('ETF (exchange-traded fund)'), findsOneWidget);
    expect(find.text('P/E ratio'), findsNothing);
    await tester.enterText(find.byType(TextField), '');

    await tester.tap(find.widgetWithText(ChoiceChip, 'Crypto'));
    await tester.pumpAndSettle();
    expect(find.text('Stablecoin'), findsOneWidget);
    expect(find.text('P/E ratio'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('P/E ratio'));
    await tester.pumpAndSettle();
    expect(find.text('Body of P/E ratio.'), findsOneWidget);
    expect(find.text('Example'), findsOneWidget);
    expect(find.text('Company value'), findsOneWidget); // category label
    // Related ids without an entry are skipped.
    expect(find.byType(OutlinedButton), findsOneWidget);
    await tester.tap(find.text('Earnings per share (EPS)'));
    await tester.pumpAndSettle();
    expect(find.text('Body of Earnings per share (EPS).'), findsOneWidget);
  });

  testWidgets('unknown search term can be asked to the copilot', (
    tester,
  ) async {
    final live = FakeLiveController([]);
    await pumpApp(
      tester,
      AuthState.authenticated(testUser()),
      overrides: [
        liveControllerProvider.overrideWith(() => live),
        chatApiProvider.overrideWithValue(FakeChatApi()),
      ],
    );
    go(tester, '/learn');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'short squeeze');
    await tester.pumpAndSettle();
    expect(find.text('No terms match “short squeeze”.'), findsOneWidget);

    await tester.tap(find.text('Ask the Copilot'));
    await tester.pumpAndSettle();
    expect(
      live.sent.single['text'],
      'What does “short squeeze” mean in investing?',
    );
    expect(find.byType(TextField), findsOneWidget); // copilot input
  });

  testWidgets('key figure sheet links the glossary and the copilot', (
    tester,
  ) async {
    await openAsset(tester);
    go(tester, '/assets/1');
    await tester.pumpAndSettle();

    await tester.tap(find.text('P/E ratio'));
    await tester.pumpAndSettle();
    expect(find.text('Ask the Copilot'), findsOneWidget);
    await tester.tap(find.text('Learn more'));
    await tester.pumpAndSettle();
    expect(find.text('Body of P/E ratio.'), findsOneWidget);
  });

  testWidgets("today's change explains itself", (tester) async {
    await openAsset(tester);
    go(tester, '/assets/1');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Change today'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining("previous trading day's closing"),
      findsOneWidget,
    );
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.textContaining("previous trading day's closing"), findsNothing);
  });

  testWidgets('copilot glossary card opens the term', (tester) async {
    await openCopilot(tester, [
      [
        {'event': 'conversation', 'conversation_id': 4, 'title': 'P/E'},
        {
          'event': 'action',
          'card': {
            'type': 'glossary_term',
            'term_id': 'pe-ratio',
            'name': 'P/E ratio',
          },
        },
        {
          'event': 'done',
          'message_id': 1,
          'text': 'P/E compares price with profit.',
          'actions': <Map<String, dynamic>>[],
          'remaining_today': 29,
        },
      ],
    ]);
    await tester.enterText(find.byType(TextField), 'What is P/E?');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(find.text('Glossary: P/E ratio'), findsOneWidget);
    expect(find.text('Undo'), findsNothing); // nothing to undo
    await tester.tap(find.text('Glossary: P/E ratio'));
    await tester.pumpAndSettle();
    expect(find.text('Body of P/E ratio.'), findsOneWidget);
  });
}
