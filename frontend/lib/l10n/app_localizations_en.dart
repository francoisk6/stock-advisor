// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Stock Adviser';

  @override
  String homeGreeting(String name) {
    return 'Hi, $name';
  }

  @override
  String get homeSubtitle =>
      'Follow stocks and crypto you care about, with daily insights in plain language.';

  @override
  String get homeComingSoonTitle => 'Coming next';

  @override
  String get homeComingSoonBody =>
      'Market data, watchlists and live charts arrive in the next phase.';

  @override
  String get disclaimer =>
      'Educational information only — not financial advice.';

  @override
  String get backendStatusTitle => 'Server status';

  @override
  String backendStatusOk(String environment) {
    return 'Connected ($environment)';
  }

  @override
  String get backendStatusError => 'Cannot reach the server';

  @override
  String get retry => 'Retry';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get orDivider => 'or';

  @override
  String get errorUnexpected => 'Something went wrong. Please try again.';

  @override
  String get errorNetwork =>
      'Can\'t reach the server. Check your internet connection and try again.';

  @override
  String get errorValidation =>
      'Some information looks wrong. Please check and try again.';

  @override
  String get errorTooManyAttempts =>
      'Too many attempts. Please wait a few minutes and try again.';

  @override
  String get errorServer =>
      'Our server had a problem. Please try again in a moment.';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get fullNameLabel => 'Your name';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get confirmPasswordLabel => 'Confirm password';

  @override
  String get currentPasswordLabel => 'Current password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get passwordRulesHint =>
      'At least 8 characters, with a letter and a number.';

  @override
  String get validationEmailRequired => 'Please enter your email.';

  @override
  String get validationEmailInvalid => 'This doesn\'t look like a valid email.';

  @override
  String get validationPasswordRequired => 'Please enter your password.';

  @override
  String get validationPasswordRules =>
      'Use at least 8 characters, with a letter and a number.';

  @override
  String get validationPasswordsDontMatch => 'The passwords don\'t match.';

  @override
  String get validationNameRequired => 'Please enter your name.';

  @override
  String get loginTitle => 'Welcome back';

  @override
  String get loginSubtitle => 'Sign in to see your markets and insights.';

  @override
  String get loginButton => 'Sign in';

  @override
  String get loginForgotPassword => 'Forgot password?';

  @override
  String get loginNoAccount => 'New here?';

  @override
  String get loginCreateAccount => 'Create an account';

  @override
  String get loginGoogleHint => 'Signed up with Google? Use the Google button.';

  @override
  String get googleContinue => 'Continue with Google';

  @override
  String get registerTitle => 'Create your account';

  @override
  String get registerSubtitle => 'Free plan. No credit card needed.';

  @override
  String get registerButton => 'Create account';

  @override
  String get registerHaveAccount => 'Already have an account?';

  @override
  String get registerSignIn => 'Sign in';

  @override
  String get registerTerms =>
      'By creating an account you understand that this app gives educational information only, not financial advice.';

  @override
  String get forgotTitle => 'Reset your password';

  @override
  String get forgotSubtitle =>
      'Enter your email and we\'ll send you a link to choose a new password.';

  @override
  String get forgotButton => 'Send reset link';

  @override
  String get backToLogin => 'Back to sign in';

  @override
  String get resetTitle => 'Choose a new password';

  @override
  String get resetButton => 'Save new password';

  @override
  String get resetSuccess => 'Your password was changed. You can now sign in.';

  @override
  String get linkIncomplete =>
      'This link is incomplete. Please open the link from your email again.';

  @override
  String get verifyInProgress => 'Confirming your email…';

  @override
  String get verifySuccessTitle => 'Email confirmed!';

  @override
  String get verifySuccessBody => 'Thanks — your account is now secured.';

  @override
  String get verifyFailedTitle => 'Link not valid';

  @override
  String get continueButton => 'Continue';

  @override
  String verifyBannerText(String email) {
    return 'Please confirm your email ($email). Check your inbox for our link.';
  }

  @override
  String get verifyBannerResend => 'Resend email';

  @override
  String get onboardingTitle => 'Let\'s personalize your copilot';

  @override
  String get onboardingEditTitle => 'Edit your investing profile';

  @override
  String onboardingStepOf(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingBack => 'Back';

  @override
  String get onboardingFinish => 'Finish';

  @override
  String get onboardingWhy =>
      'Your answers help the AI explain things at the right level. You can change them anytime.';

  @override
  String get onboardingMultiHint => 'Choose one or more.';

  @override
  String get onboardingExperienceQuestion =>
      'How much do you know about investing?';

  @override
  String get expBeginnerTitle => 'I\'m new to this';

  @override
  String get expBeginnerDesc => 'Explain things simply, step by step.';

  @override
  String get expBeginnerShort => 'Beginner';

  @override
  String get expIntermediateTitle => 'I know the basics';

  @override
  String get expIntermediateDesc =>
      'I understand stocks, crypto and charts a little.';

  @override
  String get expIntermediateShort => 'Intermediate';

  @override
  String get expAdvancedTitle => 'I invest regularly';

  @override
  String get expAdvancedDesc => 'Give me the details and the numbers.';

  @override
  String get expAdvancedShort => 'Advanced';

  @override
  String get onboardingRiskQuestion =>
      'Imagine your investment drops 20% in one month. What would you do?';

  @override
  String get riskConservativeTitle => 'Sell, to avoid losing more';

  @override
  String get riskConservativeDesc => 'Protecting my money matters most.';

  @override
  String get riskConservativeShort => 'Careful';

  @override
  String get riskBalancedTitle => 'Wait and see';

  @override
  String get riskBalancedDesc => 'Ups and downs are normal; I stay calm.';

  @override
  String get riskBalancedShort => 'Balanced';

  @override
  String get riskAggressiveTitle => 'Buy more while it\'s cheaper';

  @override
  String get riskAggressiveDesc =>
      'I accept big swings for bigger possible gains.';

  @override
  String get riskAggressiveShort => 'Bold';

  @override
  String get onboardingHorizonQuestion => 'When might you need this money?';

  @override
  String get horizonShortTitle => 'Within a year';

  @override
  String get horizonShortDesc => 'Short-term: stability matters more.';

  @override
  String get horizonMediumTitle => 'In 1 to 5 years';

  @override
  String get horizonMediumDesc => 'Medium-term: some ups and downs are OK.';

  @override
  String get horizonLongTitle => 'In more than 5 years';

  @override
  String get horizonLongDesc => 'Long-term: time can smooth out the swings.';

  @override
  String get onboardingAssetsQuestion => 'What would you like to follow?';

  @override
  String get assetStocks => 'Stocks';

  @override
  String get assetStocksDesc => 'Shares of companies';

  @override
  String get assetCrypto => 'Crypto';

  @override
  String get assetCryptoDesc => 'Bitcoin, Ethereum and more';

  @override
  String get assetEtfs => 'ETFs & funds';

  @override
  String get assetEtfsDesc => 'Many investments in one basket';

  @override
  String get assetCommodities => 'Commodities';

  @override
  String get assetCommoditiesDesc => 'Gold, oil, silver…';

  @override
  String get assetForex => 'Currencies';

  @override
  String get assetForexDesc => 'Exchange rates like EUR/USD';

  @override
  String get onboardingRegionsQuestion => 'Which markets interest you?';

  @override
  String get regionGlobal => 'Global';

  @override
  String get regionNorthAmerica => 'North America';

  @override
  String get regionEurope => 'Europe';

  @override
  String get regionMiddleEast => 'Middle East';

  @override
  String get regionAsiaPacific => 'Asia-Pacific';

  @override
  String get regionLatinAmerica => 'Latin America';

  @override
  String get regionAfrica => 'Africa';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileAccount => 'Account';

  @override
  String get profileEmailVerified => 'Verified';

  @override
  String get profileEmailNotVerified => 'Not verified';

  @override
  String profilePlan(String plan) {
    return '$plan plan';
  }

  @override
  String get profileSignInMethods => 'Sign-in methods';

  @override
  String get profileMethodPassword => 'Email & password';

  @override
  String get profileMethodGoogle => 'Google';

  @override
  String get profileInvesting => 'Your investing profile';

  @override
  String get profileEdit => 'Edit';

  @override
  String get profileExperience => 'Experience';

  @override
  String get profileRisk => 'Risk comfort';

  @override
  String get profileHorizon => 'Time horizon';

  @override
  String get profileInterests => 'Interests';

  @override
  String get profileMarkets => 'Markets';

  @override
  String get profileSecurity => 'Security';

  @override
  String get profileChangePassword => 'Change password';

  @override
  String get profileSetPassword => 'Set a password';

  @override
  String get profileSignOut => 'Sign out';

  @override
  String get profileDeleteAccount => 'Delete account';

  @override
  String get profileEditName => 'Edit name';

  @override
  String get profileNameUpdated => 'Name updated.';

  @override
  String get passwordChanged =>
      'Password saved. Your other devices were signed out.';

  @override
  String get deleteAccountTitle => 'Delete your account?';

  @override
  String get deleteAccountBody =>
      'This permanently deletes your account, your profile and all your data. This cannot be undone.';

  @override
  String get deleteAccountConfirmPassword => 'Enter your password to confirm';

  @override
  String get deleteAccountButton => 'Delete permanently';
}
