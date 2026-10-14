import '../../market/domain/market.dart';

enum AlertKind { priceAbove, priceBelow, moveUp, moveDown }

extension AlertKindJson on AlertKind {
  String get json => switch (this) {
    AlertKind.priceAbove => 'price_above',
    AlertKind.priceBelow => 'price_below',
    AlertKind.moveUp => 'move_up',
    AlertKind.moveDown => 'move_down',
  };

  /// Price alerts compare against a price; move alerts against a daily percent.
  bool get isPrice =>
      this == AlertKind.priceAbove || this == AlertKind.priceBelow;

  static AlertKind parse(String value) =>
      AlertKind.values.firstWhere((k) => k.json == value);
}

class PriceAlert {
  const PriceAlert({
    required this.id,
    required this.asset,
    required this.kind,
    required this.threshold,
    required this.notifyEmail,
    required this.isActive,
    required this.lastTriggeredAt,
  });

  factory PriceAlert.fromJson(Map<String, dynamic> json) => PriceAlert(
    id: json['id'] as int,
    asset: Asset.fromJson(json['asset'] as Map<String, dynamic>),
    kind: AlertKindJson.parse(json['kind'] as String),
    threshold: (json['threshold'] as num).toDouble(),
    notifyEmail: json['notify_email'] as bool,
    isActive: json['is_active'] as bool,
    lastTriggeredAt: json['last_triggered_at'] == null
        ? null
        : DateTime.parse('${json['last_triggered_at']}Z'),
  );

  final int id;
  final Asset asset;
  final AlertKind kind;
  final double threshold;
  final bool notifyEmail;
  final bool isActive;
  final DateTime? lastTriggeredAt;
}
