import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_adviser/features/auth/domain/auth_state.dart';

import 'helpers.dart';

void main() {
  testWidgets(
    'legal pages open from the sign-in screens and link to each other',
    (tester) async {
      tester.view.physicalSize = const Size(500, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpApp(tester, const AuthState.unauthenticated());

      expect(find.text('Privacy'), findsOneWidget);
      await tester.tap(find.text('Privacy'));
      await tester.pumpAndSettle();
      expect(find.text('Privacy policy'), findsOneWidget); // app bar title
      expect(find.text('What we collect'), findsOneWidget);
      expect(find.textContaining('**'), findsNothing); // bold rendered

      final disclaimer = find.widgetWithText(TextButton, 'Disclaimer');
      await tester.scrollUntilVisible(
        disclaimer,
        400,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(disclaimer);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('educational information, not financial advice'),
        findsOneWidget,
      );

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(
        find.text('Privacy'),
        findsOneWidget,
      ); // back on the sign-in screen
    },
  );

  testWidgets('register says what creating an account agrees to', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(tester, const AuthState.unauthenticated());
    await tester.tap(find.textContaining('Create'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('By creating an account you agree'),
      findsOneWidget,
    );
  });
}
