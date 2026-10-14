import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_adviser/features/auth/domain/auth_state.dart';
import 'package:stock_adviser/features/auth/domain/user.dart';
import 'package:stock_adviser/features/profile/data/user_api.dart';

import 'helpers.dart';

class FakeUserApi implements UserApi {
  ProfileAnswers? saved;

  @override
  Future<User> updateProfile(ProfileAnswers answers) async {
    saved = answers;
    return testUser();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('signed-out users see the login screen and its validation', (
    tester,
  ) async {
    await pumpApp(tester, const AuthState.unauthenticated());

    expect(find.text('Welcome back'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(find.text('Please enter your email.'), findsOneWidget);
    expect(find.text('Please enter your password.'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'not-an-email',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(find.text("This doesn't look like a valid email."), findsOneWidget);
  });

  testWidgets('home greets the user and lists popular assets', (tester) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      AuthState.authenticated(testUser(interests: ['stocks', 'crypto'])),
      popular: [
        testAsset(),
        testAsset(
          id: 2,
          symbol: 'BTC',
          name: 'Bitcoin',
          type: 'crypto',
          price: 83338,
          changePercent: -2.25,
          currency: 'USD',
        ),
      ],
    );

    expect(find.text('Hi, Ana'), findsOneWidget);
    expect(find.text('Popular in your markets'), findsOneWidget);
    expect(find.text('Saudi Arabian Oil Company'), findsOneWidget);
    expect(find.text('+1.50%'), findsOneWidget);
    expect(find.text('Bitcoin'), findsOneWidget);
    expect(find.text('-2.25%'), findsOneWidget);
    expect(
      find.text('Educational information only — not financial advice.'),
      findsOneWidget,
    );
    expect(find.textContaining('Please confirm your email'), findsNothing);

    // Interest filters narrow the list.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Crypto'));
    await tester.pumpAndSettle();
    expect(find.text('Bitcoin'), findsOneWidget);
    expect(find.text('Saudi Arabian Oil Company'), findsNothing);
  });

  testWidgets('unverified users see a reminder banner', (tester) async {
    await pumpApp(tester, AuthState.authenticated(testUser(verified: false)));
    expect(find.textContaining('Please confirm your email'), findsOneWidget);
    expect(find.text('Resend email'), findsOneWidget);
  });

  testWidgets('new users complete the 5-step onboarding quiz', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final api = FakeUserApi();
    await pumpApp(
      tester,
      AuthState.authenticated(testUser(onboarded: false)),
      overrides: [userApiProvider.overrideWithValue(api)],
    );

    Future<void> pick(String option, {required String button}) async {
      await tester.tap(find.text(option));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, button));
      await tester.pumpAndSettle();
    }

    expect(find.text('How much do you know about investing?'), findsOneWidget);
    // "Next" stays disabled until an answer is chosen.
    final next = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Next'),
    );
    expect(next.onPressed, isNull);

    await pick("I'm new to this", button: 'Next');
    await pick('Wait and see', button: 'Next');
    await pick('In more than 5 years', button: 'Next');
    await tester.tap(find.text('Crypto'));
    await pick('Stocks', button: 'Next');
    await pick('Middle East', button: 'Finish');

    expect(api.saved!.experienceLevel, 'beginner');
    expect(api.saved!.riskProfile, 'balanced');
    expect(api.saved!.investmentHorizon, 'long');
    expect(api.saved!.assetInterests, ['crypto', 'stocks']);
    expect(api.saved!.regionInterests, ['middle_east']);
    expect(find.text('Hi, Ana'), findsOneWidget);
  });
}
