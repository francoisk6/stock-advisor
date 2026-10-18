import '../../../l10n/app_localizations.dart';
import '../domain/market.dart';

String assetTypeLabel(AppLocalizations l, String type) => switch (type) {
  'stock' => l.typeStock,
  'etf' => l.typeEtf,
  'index' => l.typeIndex,
  'fund' => l.typeFund,
  'crypto' => l.typeCrypto,
  'forex' => l.typeForex,
  'commodity' => l.typeCommodity,
  _ => type,
};

String periodLabel(AppLocalizations l, String range) => switch (range) {
  '1D' => l.period1D,
  '1W' => l.period1W,
  '1M' => l.period1M,
  '6M' => l.period6M,
  '1Y' => l.period1Y,
  '5Y' => l.period5Y,
  _ => range,
};

/// Onboarding interest -> (asset type filter for /assets/popular, chip label).
List<(String, String)> interestFilters(
  AppLocalizations l,
  List<String> interests,
) => [
  for (final interest in interests)
    switch (interest) {
      'stocks' => ('stock', l.filterStocks),
      'etfs' => ('etf', l.filterEtfs),
      'crypto' => ('crypto', l.filterCrypto),
      'commodities' => ('commodity', l.filterCommodities),
      'forex' => ('forex', l.filterForex),
      _ => (interest, interest),
    },
];

/// (label, plain-language explanation) for a key figure. Null for unknown keys.
(String, String)? statText(
  AppLocalizations l,
  String key, {
  bool crypto = false,
}) => switch (key) {
  'market_cap' => (l.statMarketCap, l.statMarketCapHelp),
  'pe_ratio' => (l.statPeRatio, l.statPeRatioHelp),
  'dividend_yield' => (l.statDividendYield, l.statDividendYieldHelp),
  'expense_ratio' => (l.statExpenseRatio, l.statExpenseRatioHelp),
  'day_range' =>
    crypto
        ? (l.statDayRange24h, l.statDayRange24hHelp)
        : (l.statDayRange, l.statDayRangeHelp),
  'week52_range' => (l.statWeek52Range, l.statWeek52RangeHelp),
  'avg_volume' => (l.statAvgVolume, l.statAvgVolumeHelp),
  'beta' => (l.statBeta, l.statBetaHelp),
  'sector' => (l.statSector, l.statSectorHelp),
  'industry' => (l.statIndustry, l.statIndustryHelp),
  'market_cap_rank' => (l.statRank, l.statRankHelp),
  'volume_24h' => (l.statVolume24h, l.statVolume24hHelp),
  'circulating_supply' => (
    l.statCirculatingSupply,
    l.statCirculatingSupplyHelp,
  ),
  'max_supply' => (l.statMaxSupply, l.statMaxSupplyHelp),
  'all_time_high' => (l.statAllTimeHigh, l.statAllTimeHighHelp),
  'from_all_time_high' => (l.statFromAllTimeHigh, l.statFromAllTimeHighHelp),
  _ => null,
};

/// Glossary entry that explains a key figure in more depth.
String? statTerm(String key) => switch (key) {
  'market_cap' || 'market_cap_rank' => 'market-cap',
  'pe_ratio' => 'pe-ratio',
  'dividend_yield' => 'dividend-yield',
  'expense_ratio' => 'expense-ratio',
  'day_range' => 'day-range',
  'week52_range' => '52-week-range',
  'avg_volume' || 'volume_24h' => 'volume',
  'beta' => 'beta',
  'sector' || 'industry' => 'sector',
  'circulating_supply' => 'circulating-supply',
  'max_supply' => 'max-supply',
  'all_time_high' => 'all-time-high',
  'from_all_time_high' => 'drawdown',
  _ => null,
};

/// "2222.SR · Stock · Tadawul" (the exchange is skipped when it only repeats the type).
String assetSubtitle(AppLocalizations l, Asset asset) {
  final type = assetTypeLabel(l, asset.assetType);
  final exchange = asset.exchange;
  return [
    asset.symbol,
    type,
    if (exchange != null && exchange.toLowerCase() != type.toLowerCase())
      exchange,
  ].join(' · ');
}
