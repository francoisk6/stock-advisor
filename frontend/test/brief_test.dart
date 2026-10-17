import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_adviser/features/auth/domain/auth_state.dart';
import 'package:stock_adviser/features/brief/presentation/brief_card.dart';

import 'helpers.dart';

void main() {
  test('brief preview is plain text', () {
    expect(
      BriefCard.preview(
        '## Your markets\n- Bitcoin is **up**.\n\n- See [Reuters](https://x.example/a).',
      ),
      'Your markets · Bitcoin is **up**. · See Reuters.',
    );
  });

  testWidgets('home offers the brief; writing it opens a readable brief', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(tester, AuthState.authenticated(testUser()));

    expect(find.text('Your 2-minute morning brief'), findsOneWidget);
    await tester.tap(find.text("Get today's brief now"));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bitcoin is up 10%'), findsOneWidget);

    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('According to Reuters, ETF demand rose.'),
      findsOneWidget,
    );
    expect(find.textContaining('Written by AI'), findsOneWidget);
  });
}
