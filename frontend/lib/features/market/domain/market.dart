/// Mirrors the backend market schemas (`app/schemas/market.py`).
class Quote {
  const Quote({
    required this.price,
    required this.change,
    required this.changePercent,
    required this.currency,
    required this.asOf,
    required this.marketOpen,
  });

  factory Quote.fromJson(Map<String, dynamic> json) => Quote(
    price: (json['price'] as num).toDouble(),
    change: (json['change'] as num?)?.toDouble(),
    changePercent: (json['change_percent'] as num?)?.toDouble(),
    currency: json['currency'] as String,
    asOf: DateTime.parse('${json['as_of']}Z'),
    marketOpen: json['market_open'] as bool?,
  );

  final double price;
  final double? change;
  final double? changePercent;
  final String currency;
  final DateTime asOf;
  final bool? marketOpen;
}

class Asset {
  const Asset({
    required this.id,
    required this.symbol,
    required this.name,
    required this.assetType,
    required this.exchange,
    required this.region,
    required this.currency,
    required this.logoUrl,
    this.quote,
  });

  factory Asset.fromJson(Map<String, dynamic> json) => Asset(
    id: json['id'] as int,
    symbol: json['symbol'] as String,
    name: json['name'] as String,
    assetType: json['asset_type'] as String,
    exchange: json['exchange'] as String?,
    region: json['region'] as String,
    currency: json['currency'] as String?,
    logoUrl: json['logo_url'] as String?,
    quote: json['quote'] == null
        ? null
        : Quote.fromJson(json['quote'] as Map<String, dynamic>),
  );

  final int id;
  final String symbol;
  final String name;
  final String assetType;
  final String? exchange;
  final String region;
  final String? currency;
  final String? logoUrl;
  final Quote? quote;

  Asset withQuote(Quote? newQuote) => Asset(
    id: id,
    symbol: symbol,
    name: name,
    assetType: assetType,
    exchange: exchange,
    region: region,
    currency: currency,
    logoUrl: logoUrl,
    quote: newQuote,
  );
}

class Stat {
  const Stat({required this.key, required this.value, required this.unit});

  factory Stat.fromJson(Map<String, dynamic> json) => Stat(
    key: json['key'] as String,
    value: json['value'] as Object,
    unit: json['unit'] as String,
  );

  final String key;
  final Object value; // num or String
  final String unit; // number | money | percent | text | compact
}

class AssetDetail {
  const AssetDetail({
    required this.asset,
    this.inWatchlist = false,
    required this.stats,
    required this.description,
    required this.ranges,
    required this.dataSource,
  });

  factory AssetDetail.fromJson(Map<String, dynamic> json) => AssetDetail(
    asset: Asset.fromJson(json),
    inWatchlist: json['in_watchlist'] as bool? ?? false,
    stats: [
      for (final s in json['stats'] as List)
        Stat.fromJson(s as Map<String, dynamic>),
    ],
    description: json['description'] as String?,
    ranges: List<String>.from(json['ranges'] as List),
    dataSource: json['data_source'] as String,
  );

  final Asset asset;
  final bool inWatchlist;
  final List<Stat> stats;
  final String? description;
  final List<String> ranges;
  final String dataSource;
}

class Candle {
  const Candle({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });

  factory Candle.fromJson(Map<String, dynamic> json) => Candle(
    time: DateTime.parse('${json['t']}Z'),
    open: (json['o'] as num).toDouble(),
    high: (json['h'] as num).toDouble(),
    low: (json['l'] as num).toDouble(),
    close: (json['c'] as num).toDouble(),
  );

  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
}

class PriceHistory {
  const PriceHistory({
    required this.range,
    required this.currency,
    required this.candles,
  });

  factory PriceHistory.fromJson(Map<String, dynamic> json) => PriceHistory(
    range: json['range'] as String,
    currency: json['currency'] as String?,
    candles: [
      for (final c in json['candles'] as List)
        Candle.fromJson(c as Map<String, dynamic>),
    ],
  );

  final String range;
  final String? currency;
  final List<Candle> candles;

  /// Percent change from the first open to the last close of the period.
  double? get changePercent {
    if (candles.isEmpty || candles.first.open == 0) return null;
    return (candles.last.close - candles.first.open) / candles.first.open * 100;
  }
}

class NewsHeadline {
  const NewsHeadline({
    required this.title,
    required this.url,
    required this.source,
    required this.publishedAt,
  });

  factory NewsHeadline.fromJson(Map<String, dynamic> json) => NewsHeadline(
    title: json['title'] as String,
    url: json['url'] as String,
    source: json['source'] as String,
    publishedAt: DateTime.parse('${json['published_at']}Z'),
  );

  final String title;
  final String url;
  final String source;
  final DateTime publishedAt;
}
