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

  @override
  String get searchHint => 'Search stocks, crypto, currencies…';

  @override
  String get searchPrompt =>
      'Try a company name, a ticker like AAPL, or a coin like Bitcoin.';

  @override
  String searchEmpty(String query) {
    return 'No results for “$query”. Check the spelling or try the company\'s full name.';
  }

  @override
  String get popularTitle => 'Popular in your markets';

  @override
  String get popularSubtitle =>
      'Based on what you told us you\'re interested in.';

  @override
  String get popularEmpty => 'Nothing to show here yet.';

  @override
  String get filterAll => 'All';

  @override
  String get priceUnavailable => 'Price unavailable';

  @override
  String get typeStock => 'Stock';

  @override
  String get typeEtf => 'ETF';

  @override
  String get typeIndex => 'Index';

  @override
  String get typeFund => 'Fund';

  @override
  String get typeCrypto => 'Crypto';

  @override
  String get typeForex => 'Currency';

  @override
  String get typeCommodity => 'Commodity';

  @override
  String get filterStocks => 'Stocks';

  @override
  String get filterEtfs => 'ETFs';

  @override
  String get filterCrypto => 'Crypto';

  @override
  String get filterCommodities => 'Commodities';

  @override
  String get filterForex => 'Currencies';

  @override
  String get marketOpen => 'Market open';

  @override
  String get marketClosed => 'Market closed';

  @override
  String updatedAt(String time) {
    return 'Updated $time';
  }

  @override
  String get chartLine => 'Line';

  @override
  String get chartCandles => 'Candles';

  @override
  String get chartCandlesHelp =>
      'Each candle shows one period: the body spans the opening and closing price, the thin lines show the highest and lowest price. Green means the price rose, red means it fell.';

  @override
  String get chartEmpty => 'No price data for this period.';

  @override
  String rangeChange(String change, String period) {
    return '$change over $period';
  }

  @override
  String get period1D => 'the last day';

  @override
  String get period1W => 'the past week';

  @override
  String get period1M => 'the past month';

  @override
  String get period6M => 'the past 6 months';

  @override
  String get period1Y => 'the past year';

  @override
  String get period5Y => 'the past 5 years';

  @override
  String get keyFigures => 'Key figures';

  @override
  String get keyFiguresHint => 'Tap a figure to see what it means.';

  @override
  String get aboutTitle => 'About';

  @override
  String get readMore => 'Read more';

  @override
  String get showLess => 'Show less';

  @override
  String dataSourceNote(String source) {
    return 'Data: $source. Prices may be delayed.';
  }

  @override
  String get gotIt => 'Got it';

  @override
  String get statMarketCap => 'Market cap';

  @override
  String get statMarketCapHelp =>
      'The total value of all the company\'s shares (or all coins in existence). Bigger usually means a larger, more established business.';

  @override
  String get statPeRatio => 'P/E ratio';

  @override
  String get statPeRatioHelp =>
      'Share price divided by one year of profit per share — roughly how many years of today\'s profits you pay for. A high number can mean investors expect growth, or that the stock is expensive.';

  @override
  String get statDividendYield => 'Dividend yield';

  @override
  String get statDividendYieldHelp =>
      'Cash the company pays its shareholders each year, shown as a percentage of the share price.';

  @override
  String get statExpenseRatio => 'Expense ratio';

  @override
  String get statExpenseRatioHelp =>
      'The yearly fee a fund charges, as a percentage of your investment. Lower is better for you.';

  @override
  String get statDayRange => 'Day range';

  @override
  String get statDayRangeHelp =>
      'The lowest and highest price during the latest trading day.';

  @override
  String get statDayRange24h => '24h range';

  @override
  String get statDayRange24hHelp =>
      'The lowest and highest price in the last 24 hours. Crypto trades all day, every day.';

  @override
  String get statWeek52Range => '52-week range';

  @override
  String get statWeek52RangeHelp =>
      'The lowest and highest price over the past year. It shows how much the price has moved.';

  @override
  String get statAvgVolume => 'Average volume';

  @override
  String get statAvgVolumeHelp =>
      'How many shares change hands on a typical day. Higher volume usually makes it easier to buy and sell.';

  @override
  String get statBeta => 'Beta';

  @override
  String get statBetaHelp =>
      'How much the price tends to move compared with the overall market. 1 = like the market, above 1 = bigger swings, below 1 = calmer.';

  @override
  String get statSector => 'Sector';

  @override
  String get statSectorHelp =>
      'The part of the economy the company works in, such as Technology or Energy.';

  @override
  String get statIndustry => 'Industry';

  @override
  String get statIndustryHelp => 'A more specific group within the sector.';

  @override
  String get statRank => 'Rank';

  @override
  String get statRankHelp =>
      'Position among all cryptocurrencies by market cap. #1 is the largest.';

  @override
  String get statVolume24h => '24h volume';

  @override
  String get statVolume24hHelp =>
      'The total value traded in the last 24 hours. Higher means more people are buying and selling.';

  @override
  String get statCirculatingSupply => 'Circulating supply';

  @override
  String get statCirculatingSupplyHelp =>
      'How many coins exist and can be traded right now.';

  @override
  String get statMaxSupply => 'Max supply';

  @override
  String get statMaxSupplyHelp =>
      'The most coins that will ever exist. Some coins have no limit.';

  @override
  String get statAllTimeHigh => 'All-time high';

  @override
  String get statAllTimeHighHelp =>
      'The highest price this asset has ever reached.';

  @override
  String get statFromAllTimeHigh => 'From all-time high';

  @override
  String get statFromAllTimeHighHelp =>
      'How far today\'s price is from its highest price ever. −50% means it is at half its peak.';

  @override
  String get errorNotAvailable =>
      'This feature isn\'t available on the server yet. Please try again later.';

  @override
  String get watchlistTitle => 'Your watchlist';

  @override
  String get watchlistEmpty =>
      'Tap ☆ on any stock, coin or currency to follow it here.';

  @override
  String get watchlistAdd => 'Add to watchlist';

  @override
  String get watchlistRemove => 'Remove from watchlist';

  @override
  String get watchlistAdded => 'Added to your watchlist.';

  @override
  String get watchlistRemoved => 'Removed from your watchlist.';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsEmpty =>
      'No notifications yet. Create a price alert on any asset and we\'ll let you know here.';

  @override
  String get markAllRead => 'Mark all as read';

  @override
  String get viewAction => 'View';

  @override
  String unreadBadge(int count) {
    return '$count unread';
  }

  @override
  String get alertsTitle => 'Price alerts';

  @override
  String get alertsIntro =>
      'Alerts let you follow prices without watching the screen all day.';

  @override
  String get alertsEmpty =>
      'You have no alerts yet. Open any asset and tap “Create alert”.';

  @override
  String get alertCreate => 'Create alert';

  @override
  String get alertKindPriceAbove => 'Price goes above';

  @override
  String get alertKindPriceBelow => 'Price goes below';

  @override
  String get alertKindMoveUp => 'Rises by % in a day';

  @override
  String get alertKindMoveDown => 'Falls by % in a day';

  @override
  String alertDescPriceAbove(String price) {
    return 'Price goes above $price';
  }

  @override
  String alertDescPriceBelow(String price) {
    return 'Price goes below $price';
  }

  @override
  String alertDescMoveUp(String percent) {
    return 'Rises $percent or more in a day';
  }

  @override
  String alertDescMoveDown(String percent) {
    return 'Falls $percent or more in a day';
  }

  @override
  String get alertTargetPrice => 'Target price';

  @override
  String get alertDailyMove => 'Daily move (%)';

  @override
  String alertCurrentPrice(String price) {
    return 'Current price: $price';
  }

  @override
  String get alertEmail => 'Also send me an email';

  @override
  String get alertEmailUnverified =>
      'Confirm your email address to get alerts by email.';

  @override
  String get alertOneShotNote =>
      'Price alerts switch off after they fire once.';

  @override
  String get alertMoveNote =>
      'Daily-move alerts can fire at most once per day.';

  @override
  String get alertCreated => 'Alert created. We\'ll let you know.';

  @override
  String get alertDeleted => 'Alert deleted.';

  @override
  String get alertOn => 'Alert on';

  @override
  String get alertOffLabel => 'Switched off';

  @override
  String alertLastFired(String date) {
    return 'Last fired $date';
  }

  @override
  String get alertDelete => 'Delete alert';

  @override
  String get alertThresholdInvalid =>
      'Please enter a number greater than zero.';

  @override
  String get profileAlertsSection => 'Alerts & notifications';

  @override
  String get copilotTitle => 'Copilot';

  @override
  String get copilotAsk => 'Ask Copilot';

  @override
  String copilotAskAbout(String symbol) {
    return 'Ask Copilot about $symbol';
  }

  @override
  String copilotWelcome(String name) {
    return 'Hi $name! I can look up prices, explain terms in plain words, and manage your watchlist and alerts.';
  }

  @override
  String get copilotTryAsking => 'Try asking:';

  @override
  String get copilotHint => 'Ask about a stock, coin or market…';

  @override
  String get copilotSend => 'Send';

  @override
  String get copilotStop => 'Stop';

  @override
  String get copilotStopped => 'Stopped.';

  @override
  String get copilotOffline =>
      'Not connected right now. Reconnecting… please try again in a moment.';

  @override
  String get copilotDisclaimer =>
      'Copilot can make mistakes. Educational information only — not financial advice.';

  @override
  String copilotRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions left today',
      one: '1 question left today',
      zero: 'No questions left today',
    );
    return '$_temp0';
  }

  @override
  String get copilotNewChat => 'New chat';

  @override
  String get copilotHistory => 'Past chats';

  @override
  String get copilotHistoryEmpty => 'No past chats yet.';

  @override
  String get copilotDeleteChat => 'Delete chat';

  @override
  String get copilotStarterBitcoin => 'How is Bitcoin doing this week?';

  @override
  String get copilotStarterPe => 'What is a P/E ratio, in simple words?';

  @override
  String get copilotStarterWatchlist => 'How is my watchlist doing today?';

  @override
  String get copilotStarterAdd => 'Add Saudi Aramco to my watchlist';

  @override
  String copilotStarterAssetMonth(String symbol) {
    return 'How has $symbol done this month?';
  }

  @override
  String copilotStarterAssetFigures(String symbol) {
    return 'Explain $symbol\'s key figures simply';
  }

  @override
  String copilotStarterAssetRisks(String symbol) {
    return 'What are the risks of $symbol?';
  }

  @override
  String copilotStarterAssetAlert(String symbol) {
    return 'Alert me if $symbol falls 5% in a day';
  }

  @override
  String actionWatchlistAdded(String name) {
    return 'Added $name to your watchlist';
  }

  @override
  String actionWatchlistRemoved(String name) {
    return 'Removed $name from your watchlist';
  }

  @override
  String actionAlertCreated(String symbol, String description) {
    return 'Alert on $symbol: $description';
  }

  @override
  String get actionUndo => 'Undo';

  @override
  String get actionUndone => 'Undone';
}
