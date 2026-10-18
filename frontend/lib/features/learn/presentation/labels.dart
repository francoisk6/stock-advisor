import '../../../l10n/app_localizations.dart';

const glossaryCategories = [
  'basics',
  'valuation',
  'funds',
  'crypto',
  'risk',
  'portfolio',
  'trading',
  'charts',
  'economy',
];

String categoryLabel(AppLocalizations l, String category) => switch (category) {
  'basics' => l.glossaryBasics,
  'valuation' => l.glossaryValuation,
  'funds' => l.glossaryFunds,
  'crypto' => l.glossaryCrypto,
  'risk' => l.glossaryRisk,
  'portfolio' => l.glossaryPortfolio,
  'trading' => l.glossaryTrading,
  'charts' => l.glossaryCharts,
  'economy' => l.glossaryEconomy,
  _ => category,
};
