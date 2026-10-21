import '../../market/domain/market.dart';

double? _d(Object? v) => (v as num?)?.toDouble();
DateTime? _t(Object? v) => v == null ? null : DateTime.parse('${v}Z');

/// A practice buy or sell. Filled orders are the trade history.
class PracticeOrder {
  const PracticeOrder({
    required this.id,
    required this.asset,
    required this.side,
    required this.quantity,
    required this.amountUsd,
    required this.status,
    required this.createdAt,
    required this.filledAt,
    required this.filledQuantity,
    required this.price,
    required this.currency,
    required this.totalUsd,
    required this.gainUsd,
    required this.note,
  });

  factory PracticeOrder.fromJson(Map<String, dynamic> json) => PracticeOrder(
    id: json['id'] as int,
    asset: Asset.fromJson(json['asset'] as Map<String, dynamic>),
    side: json['side'] as String,
    quantity: _d(json['quantity']),
    amountUsd: _d(json['amount_usd']),
    status: json['status'] as String,
    createdAt: _t(json['created_at'])!,
    filledAt: _t(json['filled_at']),
    filledQuantity: _d(json['filled_quantity']),
    price: _d(json['price']),
    currency: json['currency'] as String?,
    totalUsd: _d(json['total_usd']),
    gainUsd: _d(json['gain_usd']),
    note: json['note'] as String?,
  );

  final int id;
  final Asset asset;
  final String side; // buy | sell
  final double? quantity;
  final double? amountUsd;
  final String status; // pending | filled | cancelled | rejected | undone
  final DateTime createdAt;
  final DateTime? filledAt;
  final double? filledQuantity;
  final double? price;
  final String? currency;
  final double? totalUsd;
  final double? gainUsd;
  final String? note;

  bool get isBuy => side == 'buy';
}

class PracticePosition {
  const PracticePosition({
    required this.asset,
    required this.quantity,
    required this.averagePrice,
    required this.currency,
    required this.price,
    required this.costUsd,
    required this.valueUsd,
    required this.gainUsd,
    required this.gainPercent,
    required this.sharePercent,
  });

  factory PracticePosition.fromJson(Map<String, dynamic> json) =>
      PracticePosition(
        asset: Asset.fromJson(json['asset'] as Map<String, dynamic>),
        quantity: _d(json['quantity'])!,
        averagePrice: _d(json['average_price'])!,
        currency: json['currency'] as String,
        price: _d(json['price']),
        costUsd: _d(json['cost_usd'])!,
        valueUsd: _d(json['value_usd']),
        gainUsd: _d(json['gain_usd']),
        gainPercent: _d(json['gain_percent']),
        sharePercent: _d(json['share_percent']),
      );

  final Asset asset;
  final double quantity;
  final double averagePrice; // in [currency]
  final String currency;
  final double? price;
  final double costUsd;
  final double? valueUsd;
  final double? gainUsd;
  final double? gainPercent;
  final double? sharePercent;
}

class PracticeAccount {
  const PracticeAccount({
    required this.startingCash,
    required this.cash,
    required this.availableCash,
    required this.positionsValue,
    required this.totalValue,
    required this.gainUsd,
    required this.gainPercent,
    required this.realizedUsd,
    required this.startedAt,
    required this.positions,
    required this.pending,
  });

  factory PracticeAccount.fromJson(Map<String, dynamic> json) =>
      PracticeAccount(
        startingCash: _d(json['starting_cash'])!,
        cash: _d(json['cash'])!,
        availableCash: _d(json['available_cash'])!,
        positionsValue: _d(json['positions_value'])!,
        totalValue: _d(json['total_value'])!,
        gainUsd: _d(json['gain_usd'])!,
        gainPercent: _d(json['gain_percent'])!,
        realizedUsd: _d(json['realized_usd'])!,
        startedAt: _t(json['started_at'])!,
        positions: [
          for (final p in json['positions'] as List)
            PracticePosition.fromJson(p as Map<String, dynamic>),
        ],
        pending: [
          for (final o in json['pending'] as List)
            PracticeOrder.fromJson(o as Map<String, dynamic>),
        ],
      );

  final double startingCash;
  final double cash;
  final double availableCash;
  final double positionsValue;
  final double totalValue;
  final double gainUsd;
  final double gainPercent;
  final double realizedUsd;
  final DateTime startedAt;
  final List<PracticePosition> positions;
  final List<PracticeOrder> pending;

  PracticePosition? positionOf(int assetId) =>
      positions.where((p) => p.asset.id == assetId).firstOrNull;
}

/// What an order would fill at right now.
class PracticeQuote {
  const PracticeQuote({
    required this.price,
    required this.currency,
    required this.usdPrice,
    required this.marketOpen,
    required this.heldQuantity,
    required this.availableCash,
  });

  factory PracticeQuote.fromJson(Map<String, dynamic> json) => PracticeQuote(
    price: _d(json['price'])!,
    currency: json['currency'] as String,
    usdPrice: _d(json['usd_price'])!,
    marketOpen: json['market_open'] as bool,
    heldQuantity: _d(json['held_quantity'])!,
    availableCash: _d(json['available_cash'])!,
  );

  final double price;
  final String currency;
  final double usdPrice;
  final bool marketOpen;
  final double heldQuantity;
  final double availableCash;
}
