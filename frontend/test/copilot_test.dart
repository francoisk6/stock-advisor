import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_adviser/features/auth/domain/auth_state.dart';
import 'package:stock_adviser/features/copilot/data/chat_api.dart';
import 'package:stock_adviser/features/copilot/presentation/rich_answer.dart';
import 'package:stock_adviser/features/live/live_controller.dart';

import 'helpers.dart';

/// Live connection stand-in: answers each question with the next scripted event list.
class FakeLiveController extends LiveController {
  FakeLiveController(this.script, {this.connected = true});

  final List<List<Map<String, dynamic>>> script;
  final bool connected;
  final sent = <Map<String, dynamic>>[];

  @override
  LiveState build() => LiveState(connected: connected);

  @override
  (String, Stream<Map<String, dynamic>>) sendChat(
    Map<String, dynamic> request,
  ) {
    sent.add(request);
    if (!connected) {
      return ('x', Stream.value({'event': 'error', 'code': 'offline'}));
    }
    final events = script.isEmpty
        ? <Map<String, dynamic>>[]
        : script.removeAt(0);
    return ('r${sent.length}', Stream.fromIterable(events));
  }

  @override
  void cancelChat(String id) {}
}

class FakeChatApi implements ChatApi {
  @override
  Future<int?> remainingToday() async => 30;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<FakeLiveController> openCopilot(
  WidgetTester tester,
  List<List<Map<String, dynamic>>> script, {
  bool connected = true,
}) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final live = FakeLiveController(script, connected: connected);
  await pumpApp(
    tester,
    AuthState.authenticated(testUser()),
    overrides: [
      liveControllerProvider.overrideWith(() => live),
      chatApiProvider.overrideWithValue(FakeChatApi()),
    ],
  );
  GoRouterHelper(tester.element(find.byType(Scaffold).first)).go('/copilot');
  await tester.pumpAndSettle();
  return live;
}

void main() {
  testWidgets('starter question streams an answer with an undoable action', (
    tester,
  ) async {
    final live = await openCopilot(tester, [
      [
        {
          'event': 'conversation',
          'conversation_id': 3,
          'title': 'Add Saudi Aramco',
        },
        {'event': 'status', 'text': 'Adding Saudi Aramco to your watchlist…'},
        {
          'event': 'action',
          'card': {
            'type': 'watchlist_added',
            'asset_id': 1,
            'symbol': '2222.SR',
            'name': 'Saudi Arabian Oil Company',
          },
        },
        {'event': 'delta', 'text': 'Something invented'},
        {'event': 'retract'},
        {'event': 'delta', 'text': 'Done! **Aramco** is now on '},
        {'event': 'delta', 'text': 'your watchlist.'},
        {
          'event': 'done',
          'message_id': 9,
          'text': 'Done! **Aramco** is now on your watchlist.',
          'actions': <Map<String, dynamic>>[],
          'remaining_today': 29,
        },
      ],
    ]);

    expect(find.textContaining('Hi Ana!'), findsOneWidget);
    expect(find.textContaining('30 questions left today'), findsOneWidget);
    expect(find.textContaining('not financial advice'), findsOneWidget);

    await tester.tap(find.text('Add Saudi Aramco to my watchlist'));
    await tester.pumpAndSettle();

    expect(live.sent.single['text'], 'Add Saudi Aramco to my watchlist');
    expect(live.sent.single['conversation_id'], isNull);
    expect(
      find.text('Add Saudi Aramco'),
      findsOneWidget,
    ); // title from the server
    expect(find.textContaining('is now on your watchlist.'), findsOneWidget);
    expect(
      find.textContaining('**'),
      findsNothing,
    ); // bold rendered, not shown raw
    expect(
      find.textContaining('Something invented'),
      findsNothing,
    ); // retracted
    expect(
      find.text('Added Saudi Arabian Oil Company to your watchlist'),
      findsOneWidget,
    );
    expect(find.textContaining('29 questions left today'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Undone'), findsOneWidget);

    // Follow-up questions continue the same conversation.
    await tester.enterText(find.byType(TextField), 'thanks');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(live.sent.last['conversation_id'], 3);
  });

  testWidgets('offline shows a friendly message', (tester) async {
    await openCopilot(tester, [], connected: false);
    await tester.tap(find.text('What is a P/E ratio, in simple words?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Not connected right now'), findsOneWidget);
  });

  testWidgets('answers render bullets, bold and source links', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RichAnswer(
            'Two things:\n- **Price** is up ([Reuters](https://news.example/a))\n'
            '* Volume is low ([WSJ](n2))',
          ),
        ),
      ),
    );
    expect(find.text('•'), findsNWidgets(2));
    expect(find.textContaining('Price is up (Reuters)'), findsOneWidget);
    expect(
      find.textContaining('Volume is low (WSJ)'),
      findsOneWidget,
    ); // pending ref
    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('https://'), findsNothing);
    expect(find.textContaining('](n2)'), findsNothing);
  });
}
