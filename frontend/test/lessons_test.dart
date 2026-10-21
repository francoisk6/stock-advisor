import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_adviser/features/auth/domain/auth_state.dart';

import 'helpers.dart';

Future<FakeLearnApi> openLearn(WidgetTester tester) async {
  tester.view.physicalSize = const Size(500, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = FakeLearnApi();
  await pumpApp(tester, AuthState.authenticated(testUser()), learn: api);
  await tester.tap(find.byTooltip('Learn'));
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('Learn tab: suggested lessons first, finished ones marked', (
    tester,
  ) async {
    await openLearn(tester);
    expect(find.text('Lessons for you'), findsOneWidget);
    expect(find.text('Risk basics'), findsOneWidget);
    expect(find.text('More lessons'), findsOneWidget);
    expect(find.textContaining('Done · 2/2 on the quiz'), findsOneWidget);
    expect(find.text('Glossary'), findsOneWidget);
  });

  testWidgets('lesson: read, check answers, see explanations, retry', (
    tester,
  ) async {
    final api = await openLearn(tester);
    await tester.tap(find.text('Risk basics'));
    await tester.pumpAndSettle();

    expect(find.text('Ups and downs'), findsOneWidget);
    expect(find.textContaining('**'), findsNothing); // bold rendered
    expect(find.widgetWithText(OutlinedButton, 'Volatility'), findsOneWidget);

    await tester.tap(find.text('Check my answers'));
    await tester.pumpAndSettle();
    expect(find.text('Answer all 2 questions first.'), findsOneWidget);
    expect(api.submitted, isEmpty);

    await tester.tap(find.text('100%'));
    await tester.tap(find.text('removes all risk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check my answers'));
    await tester.pumpAndSettle();

    expect(api.submitted.single, [1, 0]);
    expect(find.text('You got 1 out of 2.'), findsOneWidget);
    expect(find.text('Right'), findsOneWidget);
    expect(find.text('Not quite. The answer: lowers risk'), findsOneWidget);
    expect(find.text('Because 1.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Check my answers'), findsOneWidget);
    expect(find.text('Right'), findsNothing);

    // Glossary words link to their entries.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Volatility'));
    await tester.pumpAndSettle();
    expect(find.text('Body of Volatility.'), findsOneWidget);
  });
}
