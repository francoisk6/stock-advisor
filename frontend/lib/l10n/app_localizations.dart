import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Stock Adviser'**
  String get appTitle;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}'**
  String homeGreeting(String name);

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Follow stocks and crypto you care about, with daily insights in plain language.'**
  String get homeSubtitle;

  /// No description provided for @homeComingSoonTitle.
  ///
  /// In en, this message translates to:
  /// **'Coming next'**
  String get homeComingSoonTitle;

  /// No description provided for @homeComingSoonBody.
  ///
  /// In en, this message translates to:
  /// **'Market data, watchlists and live charts arrive in the next phase.'**
  String get homeComingSoonBody;

  /// No description provided for @disclaimer.
  ///
  /// In en, this message translates to:
  /// **'Educational information only — not financial advice.'**
  String get disclaimer;

  /// No description provided for @backendStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Server status'**
  String get backendStatusTitle;

  /// No description provided for @backendStatusOk.
  ///
  /// In en, this message translates to:
  /// **'Connected ({environment})'**
  String backendStatusOk(String environment);

  /// No description provided for @backendStatusError.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the server'**
  String get backendStatusError;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @orDivider.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get orDivider;

  /// No description provided for @errorUnexpected.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorUnexpected;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server. Check your internet connection and try again.'**
  String get errorNetwork;

  /// No description provided for @errorValidation.
  ///
  /// In en, this message translates to:
  /// **'Some information looks wrong. Please check and try again.'**
  String get errorValidation;

  /// No description provided for @errorTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a few minutes and try again.'**
  String get errorTooManyAttempts;

  /// No description provided for @errorServer.
  ///
  /// In en, this message translates to:
  /// **'Our server had a problem. Please try again in a moment.'**
  String get errorServer;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @fullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get fullNameLabel;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordLabel;

  /// No description provided for @currentPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPasswordLabel;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @passwordRulesHint.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters, with a letter and a number.'**
  String get passwordRulesHint;

  /// No description provided for @validationEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email.'**
  String get validationEmailRequired;

  /// No description provided for @validationEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'This doesn\'t look like a valid email.'**
  String get validationEmailInvalid;

  /// No description provided for @validationPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password.'**
  String get validationPasswordRequired;

  /// No description provided for @validationPasswordRules.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters, with a letter and a number.'**
  String get validationPasswordRules;

  /// No description provided for @validationPasswordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'The passwords don\'t match.'**
  String get validationPasswordsDontMatch;

  /// No description provided for @validationNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name.'**
  String get validationNameRequired;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to see your markets and insights.'**
  String get loginSubtitle;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginButton;

  /// No description provided for @loginForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get loginForgotPassword;

  /// No description provided for @loginNoAccount.
  ///
  /// In en, this message translates to:
  /// **'New here?'**
  String get loginNoAccount;

  /// No description provided for @loginCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get loginCreateAccount;

  /// No description provided for @loginGoogleHint.
  ///
  /// In en, this message translates to:
  /// **'Signed up with Google? Use the Google button.'**
  String get loginGoogleHint;

  /// No description provided for @googleContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get googleContinue;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Free plan. No credit card needed.'**
  String get registerSubtitle;

  /// No description provided for @registerButton.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get registerButton;

  /// No description provided for @registerHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get registerHaveAccount;

  /// No description provided for @registerSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get registerSignIn;

  /// No description provided for @registerTerms.
  ///
  /// In en, this message translates to:
  /// **'By creating an account you understand that this app gives educational information only, not financial advice.'**
  String get registerTerms;

  /// No description provided for @forgotTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get forgotTitle;

  /// No description provided for @forgotSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we\'ll send you a link to choose a new password.'**
  String get forgotSubtitle;

  /// No description provided for @forgotButton.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get forgotButton;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToLogin;

  /// No description provided for @resetTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password'**
  String get resetTitle;

  /// No description provided for @resetButton.
  ///
  /// In en, this message translates to:
  /// **'Save new password'**
  String get resetButton;

  /// No description provided for @resetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Your password was changed. You can now sign in.'**
  String get resetSuccess;

  /// No description provided for @linkIncomplete.
  ///
  /// In en, this message translates to:
  /// **'This link is incomplete. Please open the link from your email again.'**
  String get linkIncomplete;

  /// No description provided for @verifyInProgress.
  ///
  /// In en, this message translates to:
  /// **'Confirming your email…'**
  String get verifyInProgress;

  /// No description provided for @verifySuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Email confirmed!'**
  String get verifySuccessTitle;

  /// No description provided for @verifySuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Thanks — your account is now secured.'**
  String get verifySuccessBody;

  /// No description provided for @verifyFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Link not valid'**
  String get verifyFailedTitle;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @verifyBannerText.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your email ({email}). Check your inbox for our link.'**
  String verifyBannerText(String email);

  /// No description provided for @verifyBannerResend.
  ///
  /// In en, this message translates to:
  /// **'Resend email'**
  String get verifyBannerResend;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Let\'s personalize your copilot'**
  String get onboardingTitle;

  /// No description provided for @onboardingEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit your investing profile'**
  String get onboardingEditTitle;

  /// No description provided for @onboardingStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String onboardingStepOf(int current, int total);

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get onboardingBack;

  /// No description provided for @onboardingFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get onboardingFinish;

  /// No description provided for @onboardingWhy.
  ///
  /// In en, this message translates to:
  /// **'Your answers help the AI explain things at the right level. You can change them anytime.'**
  String get onboardingWhy;

  /// No description provided for @onboardingMultiHint.
  ///
  /// In en, this message translates to:
  /// **'Choose one or more.'**
  String get onboardingMultiHint;

  /// No description provided for @onboardingExperienceQuestion.
  ///
  /// In en, this message translates to:
  /// **'How much do you know about investing?'**
  String get onboardingExperienceQuestion;

  /// No description provided for @expBeginnerTitle.
  ///
  /// In en, this message translates to:
  /// **'I\'m new to this'**
  String get expBeginnerTitle;

  /// No description provided for @expBeginnerDesc.
  ///
  /// In en, this message translates to:
  /// **'Explain things simply, step by step.'**
  String get expBeginnerDesc;

  /// No description provided for @expBeginnerShort.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get expBeginnerShort;

  /// No description provided for @expIntermediateTitle.
  ///
  /// In en, this message translates to:
  /// **'I know the basics'**
  String get expIntermediateTitle;

  /// No description provided for @expIntermediateDesc.
  ///
  /// In en, this message translates to:
  /// **'I understand stocks, crypto and charts a little.'**
  String get expIntermediateDesc;

  /// No description provided for @expIntermediateShort.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get expIntermediateShort;

  /// No description provided for @expAdvancedTitle.
  ///
  /// In en, this message translates to:
  /// **'I invest regularly'**
  String get expAdvancedTitle;

  /// No description provided for @expAdvancedDesc.
  ///
  /// In en, this message translates to:
  /// **'Give me the details and the numbers.'**
  String get expAdvancedDesc;

  /// No description provided for @expAdvancedShort.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get expAdvancedShort;

  /// No description provided for @onboardingRiskQuestion.
  ///
  /// In en, this message translates to:
  /// **'Imagine your investment drops 20% in one month. What would you do?'**
  String get onboardingRiskQuestion;

  /// No description provided for @riskConservativeTitle.
  ///
  /// In en, this message translates to:
  /// **'Sell, to avoid losing more'**
  String get riskConservativeTitle;

  /// No description provided for @riskConservativeDesc.
  ///
  /// In en, this message translates to:
  /// **'Protecting my money matters most.'**
  String get riskConservativeDesc;

  /// No description provided for @riskConservativeShort.
  ///
  /// In en, this message translates to:
  /// **'Careful'**
  String get riskConservativeShort;

  /// No description provided for @riskBalancedTitle.
  ///
  /// In en, this message translates to:
  /// **'Wait and see'**
  String get riskBalancedTitle;

  /// No description provided for @riskBalancedDesc.
  ///
  /// In en, this message translates to:
  /// **'Ups and downs are normal; I stay calm.'**
  String get riskBalancedDesc;

  /// No description provided for @riskBalancedShort.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get riskBalancedShort;

  /// No description provided for @riskAggressiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Buy more while it\'s cheaper'**
  String get riskAggressiveTitle;

  /// No description provided for @riskAggressiveDesc.
  ///
  /// In en, this message translates to:
  /// **'I accept big swings for bigger possible gains.'**
  String get riskAggressiveDesc;

  /// No description provided for @riskAggressiveShort.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get riskAggressiveShort;

  /// No description provided for @onboardingHorizonQuestion.
  ///
  /// In en, this message translates to:
  /// **'When might you need this money?'**
  String get onboardingHorizonQuestion;

  /// No description provided for @horizonShortTitle.
  ///
  /// In en, this message translates to:
  /// **'Within a year'**
  String get horizonShortTitle;

  /// No description provided for @horizonShortDesc.
  ///
  /// In en, this message translates to:
  /// **'Short-term: stability matters more.'**
  String get horizonShortDesc;

  /// No description provided for @horizonMediumTitle.
  ///
  /// In en, this message translates to:
  /// **'In 1 to 5 years'**
  String get horizonMediumTitle;

  /// No description provided for @horizonMediumDesc.
  ///
  /// In en, this message translates to:
  /// **'Medium-term: some ups and downs are OK.'**
  String get horizonMediumDesc;

  /// No description provided for @horizonLongTitle.
  ///
  /// In en, this message translates to:
  /// **'In more than 5 years'**
  String get horizonLongTitle;

  /// No description provided for @horizonLongDesc.
  ///
  /// In en, this message translates to:
  /// **'Long-term: time can smooth out the swings.'**
  String get horizonLongDesc;

  /// No description provided for @onboardingAssetsQuestion.
  ///
  /// In en, this message translates to:
  /// **'What would you like to follow?'**
  String get onboardingAssetsQuestion;

  /// No description provided for @assetStocks.
  ///
  /// In en, this message translates to:
  /// **'Stocks'**
  String get assetStocks;

  /// No description provided for @assetStocksDesc.
  ///
  /// In en, this message translates to:
  /// **'Shares of companies'**
  String get assetStocksDesc;

  /// No description provided for @assetCrypto.
  ///
  /// In en, this message translates to:
  /// **'Crypto'**
  String get assetCrypto;

  /// No description provided for @assetCryptoDesc.
  ///
  /// In en, this message translates to:
  /// **'Bitcoin, Ethereum and more'**
  String get assetCryptoDesc;

  /// No description provided for @assetEtfs.
  ///
  /// In en, this message translates to:
  /// **'ETFs & funds'**
  String get assetEtfs;

  /// No description provided for @assetEtfsDesc.
  ///
  /// In en, this message translates to:
  /// **'Many investments in one basket'**
  String get assetEtfsDesc;

  /// No description provided for @assetCommodities.
  ///
  /// In en, this message translates to:
  /// **'Commodities'**
  String get assetCommodities;

  /// No description provided for @assetCommoditiesDesc.
  ///
  /// In en, this message translates to:
  /// **'Gold, oil, silver…'**
  String get assetCommoditiesDesc;

  /// No description provided for @assetForex.
  ///
  /// In en, this message translates to:
  /// **'Currencies'**
  String get assetForex;

  /// No description provided for @assetForexDesc.
  ///
  /// In en, this message translates to:
  /// **'Exchange rates like EUR/USD'**
  String get assetForexDesc;

  /// No description provided for @onboardingRegionsQuestion.
  ///
  /// In en, this message translates to:
  /// **'Which markets interest you?'**
  String get onboardingRegionsQuestion;

  /// No description provided for @regionGlobal.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get regionGlobal;

  /// No description provided for @regionNorthAmerica.
  ///
  /// In en, this message translates to:
  /// **'North America'**
  String get regionNorthAmerica;

  /// No description provided for @regionEurope.
  ///
  /// In en, this message translates to:
  /// **'Europe'**
  String get regionEurope;

  /// No description provided for @regionMiddleEast.
  ///
  /// In en, this message translates to:
  /// **'Middle East'**
  String get regionMiddleEast;

  /// No description provided for @regionAsiaPacific.
  ///
  /// In en, this message translates to:
  /// **'Asia-Pacific'**
  String get regionAsiaPacific;

  /// No description provided for @regionLatinAmerica.
  ///
  /// In en, this message translates to:
  /// **'Latin America'**
  String get regionLatinAmerica;

  /// No description provided for @regionAfrica.
  ///
  /// In en, this message translates to:
  /// **'Africa'**
  String get regionAfrica;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get profileAccount;

  /// No description provided for @profileEmailVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get profileEmailVerified;

  /// No description provided for @profileEmailNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Not verified'**
  String get profileEmailNotVerified;

  /// No description provided for @profilePlan.
  ///
  /// In en, this message translates to:
  /// **'{plan} plan'**
  String profilePlan(String plan);

  /// No description provided for @profileSignInMethods.
  ///
  /// In en, this message translates to:
  /// **'Sign-in methods'**
  String get profileSignInMethods;

  /// No description provided for @profileMethodPassword.
  ///
  /// In en, this message translates to:
  /// **'Email & password'**
  String get profileMethodPassword;

  /// No description provided for @profileMethodGoogle.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get profileMethodGoogle;

  /// No description provided for @profileInvesting.
  ///
  /// In en, this message translates to:
  /// **'Your investing profile'**
  String get profileInvesting;

  /// No description provided for @profileEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get profileEdit;

  /// No description provided for @profileExperience.
  ///
  /// In en, this message translates to:
  /// **'Experience'**
  String get profileExperience;

  /// No description provided for @profileRisk.
  ///
  /// In en, this message translates to:
  /// **'Risk comfort'**
  String get profileRisk;

  /// No description provided for @profileHorizon.
  ///
  /// In en, this message translates to:
  /// **'Time horizon'**
  String get profileHorizon;

  /// No description provided for @profileInterests.
  ///
  /// In en, this message translates to:
  /// **'Interests'**
  String get profileInterests;

  /// No description provided for @profileMarkets.
  ///
  /// In en, this message translates to:
  /// **'Markets'**
  String get profileMarkets;

  /// No description provided for @profileSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get profileSecurity;

  /// No description provided for @profileChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get profileChangePassword;

  /// No description provided for @profileSetPassword.
  ///
  /// In en, this message translates to:
  /// **'Set a password'**
  String get profileSetPassword;

  /// No description provided for @profileSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get profileSignOut;

  /// No description provided for @profileDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get profileDeleteAccount;

  /// No description provided for @profileEditName.
  ///
  /// In en, this message translates to:
  /// **'Edit name'**
  String get profileEditName;

  /// No description provided for @profileNameUpdated.
  ///
  /// In en, this message translates to:
  /// **'Name updated.'**
  String get profileNameUpdated;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password saved. Your other devices were signed out.'**
  String get passwordChanged;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your account, your profile and all your data. This cannot be undone.'**
  String get deleteAccountBody;

  /// No description provided for @deleteAccountConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to confirm'**
  String get deleteAccountConfirmPassword;

  /// No description provided for @deleteAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get deleteAccountButton;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
