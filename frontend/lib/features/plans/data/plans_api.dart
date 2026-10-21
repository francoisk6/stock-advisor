import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/plans.dart';

class PlansApi {
  const PlansApi(this._dio);

  final Dio _dio;

  Future<List<PlanInfo>> plans() async {
    final response = await _dio.get<List<dynamic>>('/plans');
    return [
      for (final p in response.data!)
        PlanInfo.fromJson(p as Map<String, dynamic>),
    ];
  }

  Future<PlanUsage> usage() async => PlanUsage.fromJson(
    (await _dio.get<Map<String, dynamic>>('/plans/usage')).data!,
  );

  /// "Tell me when Pro is ready."
  Future<PlanUsage> proInterest() async => PlanUsage.fromJson(
    (await _dio.post<Map<String, dynamic>>('/plans/pro/interest')).data!,
  );
}

final plansApiProvider = Provider<PlansApi>(
  (ref) => PlansApi(ref.watch(dioProvider)),
);

final plansProvider = FutureProvider<List<PlanInfo>>(
  (ref) => ref.watch(plansApiProvider).plans(),
);

/// Refreshed whenever the Plans screen opens (usage changes all the time).
final usageProvider = FutureProvider.autoDispose<PlanUsage>(
  (ref) => ref.watch(plansApiProvider).usage(),
);
