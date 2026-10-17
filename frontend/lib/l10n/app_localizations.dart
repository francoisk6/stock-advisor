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

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search stocks, crypto, currencies…'**
  String get searchHint;

  /// No description provided for @searchPrompt.
  ///
  /// In en, this message translates to:
  /// **'Try a company name, a ticker like AAPL, or a coin like Bitcoin.'**
  String get searchPrompt;

  /// No description provided for @searchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No results for “{query}”. Check the spelling or try the company\'s full name.'**
  String searchEmpty(String query);

  /// No description provided for @popularTitle.
  ///
  /// In en, this message translates to:
  /// **'Popular in your markets'**
  String get popularTitle;

  /// No description provided for @popularSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Based on what you told us you\'re interested in.'**
  String get popularSubtitle;

  /// No description provided for @popularEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to show here yet.'**
  String get popularEmpty;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @priceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Price unavailable'**
  String get priceUnavailable;

  /// No description provided for @typeStock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get typeStock;

  /// No description provided for @typeEtf.
  ///
  /// In en, this message translates to:
  /// **'ETF'**
  String get typeEtf;

  /// No description provided for @typeIndex.
  ///
  /// In en, this message translates to:
  /// **'Index'**
  String get typeIndex;

  /// No description provided for @typeFund.
  ///
  /// In en, this message translates to:
  /// **'Fund'**
  String get typeFund;

  /// No description provided for @typeCrypto.
  ///
  /// In en, this message translates to:
  /// **'Crypto'**
  String get typeCrypto;

  /// No description provided for @typeForex.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get typeForex;

  /// No description provided for @typeCommodity.
  ///
  /// In en, this message translates to:
  /// **'Commodity'**
  String get typeCommodity;

  /// No description provided for @filterStocks.
  ///
  /// In en, this message translates to:
  /// **'Stocks'**
  String get filterStocks;

  /// No description provided for @filterEtfs.
  ///
  /// In en, this message translates to:
  /// **'ETFs'**
  String get filterEtfs;

  /// No description provided for @filterCrypto.
  ///
  /// In en, this message translates to:
  /// **'Crypto'**
  String get filterCrypto;

  /// No description provided for @filterCommodities.
  ///
  /// In en, this message translates to:
  /// **'Commodities'**
  String get filterCommodities;

  /// No description provided for @filterForex.
  ///
  /// In en, this message translates to:
  /// **'Currencies'**
  String get filterForex;

  /// No description provided for @marketOpen.
  ///
  /// In en, this message translates to:
  /// **'Market open'**
  String get marketOpen;

  /// No description provided for @marketClosed.
  ///
  /// In en, this message translates to:
  /// **'Market closed'**
  String get marketClosed;

  /// No description provided for @updatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated {time}'**
  String updatedAt(String time);

  /// No description provided for @chartLine.
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get chartLine;

  /// No description provided for @chartCandles.
  ///
  /// In en, this message translates to:
  /// **'Candles'**
  String get chartCandles;

  /// No description provided for @chartCandlesHelp.
  ///
  /// In en, this message translates to:
  /// **'Each candle shows one period: the body spans the opening and closing price, the thin lines show the highest and lowest price. Green means the price rose, red means it fell.'**
  String get chartCandlesHelp;

  /// No description provided for @chartEmpty.
  ///
  /// In en, this message translates to:
  /// **'No price data for this period.'**
  String get chartEmpty;

  /// No description provided for @rangeChange.
  ///
  /// In en, this message translates to:
  /// **'{change} over {period}'**
  String rangeChange(String change, String period);

  /// No description provided for @period1D.
  ///
  /// In en, this message translates to:
  /// **'the last day'**
  String get period1D;

  /// No description provided for @period1W.
  ///
  /// In en, this message translates to:
  /// **'the past week'**
  String get period1W;

  /// No description provided for @period1M.
  ///
  /// In en, this message translates to:
  /// **'the past month'**
  String get period1M;

  /// No description provided for @period6M.
  ///
  /// In en, this message translates to:
  /// **'the past 6 months'**
  String get period6M;

  /// No description provided for @period1Y.
  ///
  /// In en, this message translates to:
  /// **'the past year'**
  String get period1Y;

  /// No description provided for @period5Y.
  ///
  /// In en, this message translates to:
  /// **'the past 5 years'**
  String get period5Y;

  /// No description provided for @keyFigures.
  ///
  /// In en, this message translates to:
  /// **'Key figures'**
  String get keyFigures;

  /// No description provided for @keyFiguresHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a figure to see what it means.'**
  String get keyFiguresHint;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @readMore.
  ///
  /// In en, this message translates to:
  /// **'Read more'**
  String get readMore;

  /// No description provided for @showLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get showLess;

  /// No description provided for @dataSourceNote.
  ///
  /// In en, this message translates to:
  /// **'Data: {source}. Prices may be delayed.'**
  String dataSourceNote(String source);

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @statMarketCap.
  ///
  /// In en, this message translates to:
  /// **'Market cap'**
  String get statMarketCap;

  /// No description provided for @statMarketCapHelp.
  ///
  /// In en, this message translates to:
  /// **'The total value of all the company\'s shares (or all coins in existence). Bigger usually means a larger, more established business.'**
  String get statMarketCapHelp;

  /// No description provided for @statPeRatio.
  ///
  /// In en, this message translates to:
  /// **'P/E ratio'**
  String get statPeRatio;

  /// No description provided for @statPeRatioHelp.
  ///
  /// In en, this message translates to:
  /// **'Share price divided by one year of profit per share — roughly how many years of today\'s profits you pay for. A high number can mean investors expect growth, or that the stock is expensive.'**
  String get statPeRatioHelp;

  /// No description provided for @statDividendYield.
  ///
  /// In en, this message translates to:
  /// **'Dividend yield'**
  String get statDividendYield;

  /// No description provided for @statDividendYieldHelp.
  ///
  /// In en, this message translates to:
  /// **'Cash the company pays its shareholders each year, shown as a percentage of the share price.'**
  String get statDividendYieldHelp;

  /// No description provided for @statExpenseRatio.
  ///
  /// In en, this message translates to:
  /// **'Expense ratio'**
  String get statExpenseRatio;

  /// No description provided for @statExpenseRatioHelp.
  ///
  /// In en, this message translates to:
  /// **'The yearly fee a fund charges, as a percentage of your investment. Lower is better for you.'**
  String get statExpenseRatioHelp;

  /// No description provided for @statDayRange.
  ///
  /// In en, this message translates to:
  /// **'Day range'**
  String get statDayRange;

  /// No description provided for @statDayRangeHelp.
  ///
  /// In en, this message translates to:
  /// **'The lowest and highest price during the latest trading day.'**
  String get statDayRangeHelp;

  /// No description provided for @statDayRange24h.
  ///
  /// In en, this message translates to:
  /// **'24h range'**
  String get statDayRange24h;

  /// No description provided for @statDayRange24hHelp.
  ///
  /// In en, this message translates to:
  /// **'The lowest and highest price in the last 24 hours. Crypto trades all day, every day.'**
  String get statDayRange24hHelp;

  /// No description provided for @statWeek52Range.
  ///
  /// In en, this message translates to:
  /// **'52-week range'**
  String get statWeek52Range;

  /// No description provided for @statWeek52RangeHelp.
  ///
  /// In en, this message translates to:
  /// **'The lowest and highest price over the past year. It shows how much the price has moved.'**
  String get statWeek52RangeHelp;

  /// No description provided for @statAvgVolume.
  ///
  /// In en, this message translates to:
  /// **'Average volume'**
  String get statAvgVolume;

  /// No description provided for @statAvgVolumeHelp.
  ///
  /// In en, this message translates to:
  /// **'How many shares change hands on a typical day. Higher volume usually makes it easier to buy and sell.'**
  String get statAvgVolumeHelp;

  /// No description provided for @statBeta.
  ///
  /// In en, this message translates to:
  /// **'Beta'**
  String get statBeta;

  /// No description provided for @statBetaHelp.
  ///
  /// In en, this message translates to:
  /// **'How much the price tends to move compared with the overall market. 1 = like the market, above 1 = bigger swings, below 1 = calmer.'**
  String get statBetaHelp;

  /// No description provided for @statSector.
  ///
  /// In en, this message translates to:
  /// **'Sector'**
  String get statSector;

  /// No description provided for @statSectorHelp.
  ///
  /// In en, this message translates to:
  /// **'The part of the economy the company works in, such as Technology or Energy.'**
  String get statSectorHelp;

  /// No description provided for @statIndustry.
  ///
  /// In en, this message translates to:
  /// **'Industry'**
  String get statIndustry;

  /// No description provided for @statIndustryHelp.
  ///
  /// In en, this message translates to:
  /// **'A more specific group within the sector.'**
  String get statIndustryHelp;

  /// No description provided for @statRank.
  ///
  /// In en, this message translates to:
  /// **'Rank'**
  String get statRank;

  /// No description provided for @statRankHelp.
  ///
  /// In en, this message translates to:
  /// **'Position among all cryptocurrencies by market cap. #1 is the largest.'**
  String get statRankHelp;

  /// No description provided for @statVolume24h.
  ///
  /// In en, this message translates to:
  /// **'24h volume'**
  String get statVolume24h;

  /// No description provided for @statVolume24hHelp.
  ///
  /// In en, this message translates to:
  /// **'The total value traded in the last 24 hours. Higher means more people are buying and selling.'**
  String get statVolume24hHelp;

  /// No description provided for @statCirculatingSupply.
  ///
  /// In en, this message translates to:
  /// **'Circulating supply'**
  String get statCirculatingSupply;

  /// No description provided for @statCirculatingSupplyHelp.
  ///
  /// In en, this message translates to:
  /// **'How many coins exist and can be traded right now.'**
  String get statCirculatingSupplyHelp;

  /// No description provided for @statMaxSupply.
  ///
  /// In en, this message translates to:
  /// **'Max supply'**
  String get statMaxSupply;

  /// No description provided for @statMaxSupplyHelp.
  ///
  /// In en, this message translates to:
  /// **'The most coins that will ever exist. Some coins have no limit.'**
  String get statMaxSupplyHelp;

  /// No description provided for @statAllTimeHigh.
  ///
  /// In en, this message translates to:
  /// **'All-time high'**
  String get statAllTimeHigh;

  /// No description provided for @statAllTimeHighHelp.
  ///
  /// In en, this message translates to:
  /// **'The highest price this asset has ever reached.'**
  String get statAllTimeHighHelp;

  /// No description provided for @statFromAllTimeHigh.
  ///
  /// In en, this message translates to:
  /// **'From all-time high'**
  String get statFromAllTimeHigh;

  /// No description provided for @statFromAllTimeHighHelp.
  ///
  /// In en, this message translates to:
  /// **'How far today\'s price is from its highest price ever. −50% means it is at half its peak.'**
  String get statFromAllTimeHighHelp;

  /// No description provided for @errorNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'This feature isn\'t available on the server yet. Please try again later.'**
  String get errorNotAvailable;

  /// No description provided for @watchlistTitle.
  ///
  /// In en, this message translates to:
  /// **'Your watchlist'**
  String get watchlistTitle;

  /// No description provided for @watchlistEmpty.
  ///
  /// In en, this message translates to:
  /// **'Tap ☆ on any stock, coin or currency to follow it here.'**
  String get watchlistEmpty;

  /// No description provided for @watchlistAdd.
  ///
  /// In en, this message translates to:
  /// **'Add to watchlist'**
  String get watchlistAdd;

  /// No description provided for @watchlistRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from watchlist'**
  String get watchlistRemove;

  /// No description provided for @watchlistAdded.
  ///
  /// In en, this message translates to:
  /// **'Added to your watchlist.'**
  String get watchlistAdded;

  /// No description provided for @watchlistRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed from your watchlist.'**
  String get watchlistRemoved;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet. Create a price alert on any asset and we\'ll let you know here.'**
  String get notificationsEmpty;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get markAllRead;

  /// No description provided for @viewAction.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get viewAction;

  /// No description provided for @unreadBadge.
  ///
  /// In en, this message translates to:
  /// **'{count} unread'**
  String unreadBadge(int count);

  /// No description provided for @alertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Price alerts'**
  String get alertsTitle;

  /// No description provided for @alertsIntro.
  ///
  /// In en, this message translates to:
  /// **'Alerts let you follow prices without watching the screen all day.'**
  String get alertsIntro;

  /// No description provided for @alertsEmpty.
  ///
  /// In en, this message translates to:
  /// **'You have no alerts yet. Open any asset and tap “Create alert”.'**
  String get alertsEmpty;

  /// No description provided for @alertCreate.
  ///
  /// In en, this message translates to:
  /// **'Create alert'**
  String get alertCreate;

  /// No description provided for @alertKindPriceAbove.
  ///
  /// In en, this message translates to:
  /// **'Price goes above'**
  String get alertKindPriceAbove;

  /// No description provided for @alertKindPriceBelow.
  ///
  /// In en, this message translates to:
  /// **'Price goes below'**
  String get alertKindPriceBelow;

  /// No description provided for @alertKindMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Rises by % in a day'**
  String get alertKindMoveUp;

  /// No description provided for @alertKindMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Falls by % in a day'**
  String get alertKindMoveDown;

  /// No description provided for @alertDescPriceAbove.
  ///
  /// In en, this message translates to:
  /// **'Price goes above {price}'**
  String alertDescPriceAbove(String price);

  /// No description provided for @alertDescPriceBelow.
  ///
  /// In en, this message translates to:
  /// **'Price goes below {price}'**
  String alertDescPriceBelow(String price);

  /// No description provided for @alertDescMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Rises {percent} or more in a day'**
  String alertDescMoveUp(String percent);

  /// No description provided for @alertDescMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Falls {percent} or more in a day'**
  String alertDescMoveDown(String percent);

  /// No description provided for @alertTargetPrice.
  ///
  /// In en, this message translates to:
  /// **'Target price'**
  String get alertTargetPrice;

  /// No description provided for @alertDailyMove.
  ///
  /// In en, this message translates to:
  /// **'Daily move (%)'**
  String get alertDailyMove;

  /// No description provided for @alertCurrentPrice.
  ///
  /// In en, this message translates to:
  /// **'Current price: {price}'**
  String alertCurrentPrice(String price);

  /// No description provided for @alertEmail.
  ///
  /// In en, this message translates to:
  /// **'Also send me an email'**
  String get alertEmail;

  /// No description provided for @alertEmailUnverified.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email address to get alerts by email.'**
  String get alertEmailUnverified;

  /// No description provided for @alertOneShotNote.
  ///
  /// In en, this message translates to:
  /// **'Price alerts switch off after they fire once.'**
  String get alertOneShotNote;

  /// No description provided for @alertMoveNote.
  ///
  /// In en, this message translates to:
  /// **'Daily-move alerts can fire at most once per day.'**
  String get alertMoveNote;

  /// No description provided for @alertCreated.
  ///
  /// In en, this message translates to:
  /// **'Alert created. We\'ll let you know.'**
  String get alertCreated;

  /// No description provided for @alertDeleted.
  ///
  /// In en, this message translates to:
  /// **'Alert deleted.'**
  String get alertDeleted;

  /// No description provided for @alertOn.
  ///
  /// In en, this message translates to:
  /// **'Alert on'**
  String get alertOn;

  /// No description provided for @alertOffLabel.
  ///
  /// In en, this message translates to:
  /// **'Switched off'**
  String get alertOffLabel;

  /// No description provided for @alertLastFired.
  ///
  /// In en, this message translates to:
  /// **'Last fired {date}'**
  String alertLastFired(String date);

  /// No description provided for @alertDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete alert'**
  String get alertDelete;

  /// No description provided for @alertThresholdInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a number greater than zero.'**
  String get alertThresholdInvalid;

  /// No description provided for @profileAlertsSection.
  ///
  /// In en, this message translates to:
  /// **'Alerts & notifications'**
  String get profileAlertsSection;

  /// No description provided for @copilotTitle.
  ///
  /// In en, this message translates to:
  /// **'Copilot'**
  String get copilotTitle;

  /// No description provided for @copilotAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask Copilot'**
  String get copilotAsk;

  /// No description provided for @copilotAskAbout.
  ///
  /// In en, this message translates to:
  /// **'Ask Copilot about {symbol}'**
  String copilotAskAbout(String symbol);

  /// No description provided for @copilotWelcome.
  ///
  /// In en, this message translates to:
  /// **'Hi {name}! I can look up prices, explain terms in plain words, and manage your watchlist and alerts.'**
  String copilotWelcome(String name);

  /// No description provided for @copilotTryAsking.
  ///
  /// In en, this message translates to:
  /// **'Try asking:'**
  String get copilotTryAsking;

  /// No description provided for @copilotHint.
  ///
  /// In en, this message translates to:
  /// **'Ask about a stock, coin or market…'**
  String get copilotHint;

  /// No description provided for @copilotSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get copilotSend;

  /// No description provided for @copilotStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get copilotStop;

  /// No description provided for @copilotStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped.'**
  String get copilotStopped;

  /// No description provided for @copilotOffline.
  ///
  /// In en, this message translates to:
  /// **'Not connected right now. Reconnecting… please try again in a moment.'**
  String get copilotOffline;

  /// No description provided for @copilotDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Copilot can make mistakes. Educational information only — not financial advice.'**
  String get copilotDisclaimer;

  /// No description provided for @copilotRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No questions left today} =1{1 question left today} other{{count} questions left today}}'**
  String copilotRemaining(int count);

  /// No description provided for @copilotNewChat.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get copilotNewChat;

  /// No description provided for @copilotHistory.
  ///
  /// In en, this message translates to:
  /// **'Past chats'**
  String get copilotHistory;

  /// No description provided for @copilotHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No past chats yet.'**
  String get copilotHistoryEmpty;

  /// No description provided for @copilotDeleteChat.
  ///
  /// In en, this message translates to:
  /// **'Delete chat'**
  String get copilotDeleteChat;

  /// No description provided for @copilotStarterBitcoin.
  ///
  /// In en, this message translates to:
  /// **'How is Bitcoin doing this week?'**
  String get copilotStarterBitcoin;

  /// No description provided for @copilotStarterPe.
  ///
  /// In en, this message translates to:
  /// **'What is a P/E ratio, in simple words?'**
  String get copilotStarterPe;

  /// No description provided for @copilotStarterWatchlist.
  ///
  /// In en, this message translates to:
  /// **'How is my watchlist doing today?'**
  String get copilotStarterWatchlist;

  /// No description provided for @copilotStarterAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Saudi Aramco to my watchlist'**
  String get copilotStarterAdd;

  /// No description provided for @copilotStarterAssetMonth.
  ///
  /// In en, this message translates to:
  /// **'How has {symbol} done this month?'**
  String copilotStarterAssetMonth(String symbol);

  /// No description provided for @copilotStarterAssetFigures.
  ///
  /// In en, this message translates to:
  /// **'Explain {symbol}\'s key figures simply'**
  String copilotStarterAssetFigures(String symbol);

  /// No description provided for @copilotStarterAssetRisks.
  ///
  /// In en, this message translates to:
  /// **'What are the risks of {symbol}?'**
  String copilotStarterAssetRisks(String symbol);

  /// No description provided for @copilotStarterAssetAlert.
  ///
  /// In en, this message translates to:
  /// **'Alert me if {symbol} falls 5% in a day'**
  String copilotStarterAssetAlert(String symbol);

  /// No description provided for @actionWatchlistAdded.
  ///
  /// In en, this message translates to:
  /// **'Added {name} to your watchlist'**
  String actionWatchlistAdded(String name);

  /// No description provided for @actionWatchlistRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed {name} from your watchlist'**
  String actionWatchlistRemoved(String name);

  /// No description provided for @actionAlertCreated.
  ///
  /// In en, this message translates to:
  /// **'Alert on {symbol}: {description}'**
  String actionAlertCreated(String symbol, String description);

  /// No description provided for @actionUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get actionUndo;

  /// No description provided for @actionUndone.
  ///
  /// In en, this message translates to:
  /// **'Undone'**
  String get actionUndone;

  /// No description provided for @newsTitle.
  ///
  /// In en, this message translates to:
  /// **'Latest news'**
  String get newsTitle;

  /// No description provided for @newsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No recent news found.'**
  String get newsEmpty;

  /// No description provided for @newsSourceTime.
  ///
  /// In en, this message translates to:
  /// **'{source} · {time}'**
  String newsSourceTime(String source, String time);

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute ago} other{{count} minutes ago}}'**
  String timeMinutesAgo(int count);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String timeHoursAgo(int count);

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{yesterday} other{{count} days ago}}'**
  String timeDaysAgo(int count);

  /// No description provided for @newsNote.
  ///
  /// In en, this message translates to:
  /// **'Headlines from Google News. Opening one takes you to the publisher\'s site.'**
  String get newsNote;
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
