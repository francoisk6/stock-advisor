/// A plan as offered (Free / Pro). A null limit means unlimited.
class PlanInfo {
  const PlanInfo({
    required this.code,
    required this.name,
    required this.priceMonthlyUsd,
    required this.priceYearlyUsd,
    required this.forSale,
    required this.limits,
  });

  factory PlanInfo.fromJson(Map<String, dynamic> json) => PlanInfo(
    code: json['code'] as String,
    name: json['name'] as String,
    priceMonthlyUsd: (json['price_monthly_usd'] as num?)?.toDouble(),
    priceYearlyUsd: (json['price_yearly_usd'] as num?)?.toDouble(),
    forSale: json['for_sale'] as bool,
    limits: (json['limits'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, v as int?),
    ),
  );

  final String code;
  final String name;
  final double? priceMonthlyUsd;
  final double? priceYearlyUsd;
  final bool forSale;
  final Map<String, int?> limits;
}

class UsageItem {
  const UsageItem(this.key, this.used, this.limit);

  final String key;
  final int used;
  final int? limit;
}

class PlanUsage {
  const PlanUsage({
    required this.plan,
    required this.planName,
    required this.items,
    required this.proInterest,
  });

  factory PlanUsage.fromJson(Map<String, dynamic> json) => PlanUsage(
    plan: json['plan'] as String,
    planName: json['plan_name'] as String,
    items: [
      for (final i in json['items'] as List)
        UsageItem(i['key'] as String, i['used'] as int, i['limit'] as int?),
    ],
    proInterest: json['pro_interest_at'] != null,
  );

  final String plan;
  final String planName;
  final List<UsageItem> items;
  final bool proInterest;
}
