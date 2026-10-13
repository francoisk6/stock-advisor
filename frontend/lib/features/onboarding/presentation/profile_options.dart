import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// One answer in the onboarding quiz. [code] is the value stored by the backend.
class ProfileOption {
  const ProfileOption(
    this.code,
    this.icon,
    this.title,
    this.description,
    this.short,
  );

  final String code;
  final IconData icon;
  final String title;
  final String description;
  final String short;
}

List<ProfileOption> experienceOptions(AppLocalizations l) => [
  ProfileOption(
    'beginner',
    Icons.school_outlined,
    l.expBeginnerTitle,
    l.expBeginnerDesc,
    l.expBeginnerShort,
  ),
  ProfileOption(
    'intermediate',
    Icons.trending_up,
    l.expIntermediateTitle,
    l.expIntermediateDesc,
    l.expIntermediateShort,
  ),
  ProfileOption(
    'advanced',
    Icons.query_stats,
    l.expAdvancedTitle,
    l.expAdvancedDesc,
    l.expAdvancedShort,
  ),
];

List<ProfileOption> riskOptions(AppLocalizations l) => [
  ProfileOption(
    'conservative',
    Icons.shield_outlined,
    l.riskConservativeTitle,
    l.riskConservativeDesc,
    l.riskConservativeShort,
  ),
  ProfileOption(
    'balanced',
    Icons.balance,
    l.riskBalancedTitle,
    l.riskBalancedDesc,
    l.riskBalancedShort,
  ),
  ProfileOption(
    'aggressive',
    Icons.rocket_launch_outlined,
    l.riskAggressiveTitle,
    l.riskAggressiveDesc,
    l.riskAggressiveShort,
  ),
];

List<ProfileOption> horizonOptions(AppLocalizations l) => [
  ProfileOption(
    'short',
    Icons.event,
    l.horizonShortTitle,
    l.horizonShortDesc,
    l.horizonShortTitle,
  ),
  ProfileOption(
    'medium',
    Icons.date_range,
    l.horizonMediumTitle,
    l.horizonMediumDesc,
    l.horizonMediumTitle,
  ),
  ProfileOption(
    'long',
    Icons.forest_outlined,
    l.horizonLongTitle,
    l.horizonLongDesc,
    l.horizonLongTitle,
  ),
];

List<ProfileOption> assetOptions(AppLocalizations l) => [
  ProfileOption(
    'stocks',
    Icons.business,
    l.assetStocks,
    l.assetStocksDesc,
    l.assetStocks,
  ),
  ProfileOption(
    'crypto',
    Icons.currency_bitcoin,
    l.assetCrypto,
    l.assetCryptoDesc,
    l.assetCrypto,
  ),
  ProfileOption(
    'etfs',
    Icons.pie_chart_outline,
    l.assetEtfs,
    l.assetEtfsDesc,
    l.assetEtfs,
  ),
  ProfileOption(
    'commodities',
    Icons.diamond_outlined,
    l.assetCommodities,
    l.assetCommoditiesDesc,
    l.assetCommodities,
  ),
  ProfileOption(
    'forex',
    Icons.currency_exchange,
    l.assetForex,
    l.assetForexDesc,
    l.assetForex,
  ),
];

List<ProfileOption> regionOptions(AppLocalizations l) => [
  ProfileOption('global', Icons.public, l.regionGlobal, '', l.regionGlobal),
  ProfileOption(
    'north_america',
    Icons.location_on_outlined,
    l.regionNorthAmerica,
    '',
    l.regionNorthAmerica,
  ),
  ProfileOption(
    'europe',
    Icons.location_on_outlined,
    l.regionEurope,
    '',
    l.regionEurope,
  ),
  ProfileOption(
    'middle_east',
    Icons.location_on_outlined,
    l.regionMiddleEast,
    '',
    l.regionMiddleEast,
  ),
  ProfileOption(
    'asia_pacific',
    Icons.location_on_outlined,
    l.regionAsiaPacific,
    '',
    l.regionAsiaPacific,
  ),
  ProfileOption(
    'latin_america',
    Icons.location_on_outlined,
    l.regionLatinAmerica,
    '',
    l.regionLatinAmerica,
  ),
  ProfileOption(
    'africa',
    Icons.location_on_outlined,
    l.regionAfrica,
    '',
    l.regionAfrica,
  ),
];

/// Short label for a stored code, e.g. "balanced" -> "Balanced".
String optionLabel(List<ProfileOption> options, String? code) =>
    options.where((o) => o.code == code).map((o) => o.short).firstOrNull ?? '—';
