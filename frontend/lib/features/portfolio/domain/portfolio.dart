import '../../market/domain/market.dart';

double? _d(Object? v) => (v as num?)?.toDouble();

/// Something the user really owns, entered by hand. Values are in the portfolio currency;
/// [averagePrice] and [price] are in the asset's own [currency].
class Holding {
  const Holding({
    required this.id,
    required this.asset,
    required this.quantity,
    required this.averagePrice,
    required this.currency,
    required this.boughtOn,
    required this.note,
    required this.price,
    required this.value,
    required this.gain,
    required this.gainPercent,
    required this.sharePercent,
  });

  factory Holding.fromJson(Map<String, dynamic> json) => Holding(
    id: json['id'] as int,
    asset: Asset.fromJson(json['asset'] as Map<String, dynamic>),
    quantity: _d(json['quantity'])!,
    averagePrice: _d(json['average_price'])!,
    currency: json['currency'] as String,
    boughtOn: json['bought_on'] == null
        ? null
        : DateTime.parse(json['bought_on'] as String),
    note: json['note'] as String?,
    price: _d(json['price']),
    value: _d(json['value']),
    gain: _d(json['gain']),
    gainPercent: _d(json['gain_percent']),
    sharePercent: _d(json['share_percent']),
  );

  final int id;
  final Asset asset;
  final double quantity;
  final double averagePrice;
  final String currency;
  final DateTime? boughtOn;
  final String? note;
  final double? price;
  final double? value;
  final double? gain;
  final double? gainPercent;
  final double? sharePercent;
}

class Slice {
  const Slice(this.key, this.value, this.percent);

  factory Slice.fromJson(Map<String, dynamic> json) =>
      Slice(json['key'] as String, _d(json['value'])!, _d(json['percent'])!);

  final String key;
  final double value;
  final double percent;
}

/// One note of the risk overview: a code the app words, with its numbers.
class RiskNote {
  const RiskNote(this.code, this.level, this.params);

  factory RiskNote.fromJson(Map<String, dynamic> json) => RiskNote(
    json['code'] as String,
    json['level'] as String,
    json['params'] as Map<String, dynamic>,
  );

  final String code;
  final String level; // caution | good
  final Map<String, dynamic> params;
}

class Portfolio {
  const Portfolio({
    required this.currency,
    required this.totalValue,
    required this.totalCost,
    required this.gain,
    required this.gainPercent,
    required this.dayChange,
    required this.holdings,
    required this.byType,
    required this.byRegion,
    required this.byCurrency,
    required this.risks,
  });

  factory Portfolio.fromJson(Map<String, dynamic> json) {
    List<Slice> slices(String key) => [
      for (final s in json[key] as List)
        Slice.fromJson(s as Map<String, dynamic>),
    ];
    return Portfolio(
      currency: json['currency'] as String,
      totalValue: _d(json['total_value'])!,
      totalCost: _d(json['total_cost'])!,
      gain: _d(json['gain'])!,
      gainPercent: _d(json['gain_percent']),
      dayChange: _d(json['day_change'])!,
      holdings: [
        for (final h in json['holdings'] as List)
          Holding.fromJson(h as Map<String, dynamic>),
      ],
      byType: slices('by_type'),
      byRegion: slices('by_region'),
      byCurrency: slices('by_currency'),
      risks: [
        for (final r in json['risks'] as List)
          RiskNote.fromJson(r as Map<String, dynamic>),
      ],
    );
  }

  final String currency;
  final double totalValue;
  final double totalCost;
  final double gain;
  final double? gainPercent;
  final double dayChange;
  final List<Holding> holdings;
  final List<Slice> byType;
  final List<Slice> byRegion;
  final List<Slice> byCurrency;
  final List<RiskNote> risks;

  Holding? holdingOf(int assetId) =>
      holdings.where((h) => h.asset.id == assetId).firstOrNull;
}
