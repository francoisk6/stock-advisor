import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_adviser/features/auth/domain/auth_state.dart';
import 'package:stock_adviser/features/market/data/market_api.dart';

import 'helpers.dart';
import 'market_test.dart' show FakeMarketApi;

Future<void> openApp(WidgetTester tester, {required double width}) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpApp(
    tester,
    AuthState.authenticated(testUser()),
    overrides: [marketApiProvider.overrideWithValue(FakeMarketApi())],
    practice: FakePracticeApi(account: testPracticeAccount(holding: true)),
  );
}

String location(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first)).state.uri.path;

void main() {
  testWidgets('phones: bottom bar with four tabs that keep their place', (
    tester,
  ) async {
    await openApp(tester, width: 400);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    await tester.tap(find.byTooltip('Learn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('P/E ratio'));
    await tester.pumpAndSettle();
    expect(location(tester), '/learn/pe-ratio');

    // An asset opened from Practice stays in the Practice tab ("back" returns there).
    await tester.tap(find.byTooltip('Practice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apple Inc.'));
    await tester.pumpAndSettle();
    expect(location(tester), '/practice/assets/1');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(location(tester), '/practice');

    // Coming back to Learn shows the term that was open.
    await tester.tap(find.byTooltip('Learn'));
    await tester.pumpAndSettle();
    expect(find.text('Body of P/E ratio.'), findsOneWidget);
    // Tapping the current tab again returns to its first page.
    await tester.tap(find.byTooltip('Learn'));
    await tester.pumpAndSettle();
    expect(location(tester), '/learn');

    await tester.tap(find.byTooltip('Home'));
    await tester.pumpAndSettle();
    expect(location(tester), '/');
  });

  for (final width in [400.0, 1200.0]) {
    testWidgets('screen readers see the tabs (width $width)', (tester) async {
      final semantics = tester.ensureSemantics();
      await openApp(tester, width: width);
      for (final tab in ['Home', 'Portfolio', 'Practice', 'Learn']) {
        expect(
          find.bySemanticsLabel(RegExp('^$tab')),
          findsOneWidget,
          reason: tab,
        );
      }
      semantics.dispose();
    });
  }

  testWidgets('wide screens: side rail instead of the bottom bar', (
    tester,
  ) async {
    await openApp(tester, width: 1200);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.text('Portfolio'));
    await tester.pumpAndSettle();
    expect(location(tester), '/portfolio');
  });
}
