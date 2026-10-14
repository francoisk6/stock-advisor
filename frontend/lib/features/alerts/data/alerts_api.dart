import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/alert.dart';

class AlertsApi {
  const AlertsApi(this._dio);

  final Dio _dio;

  Future<List<PriceAlert>> list({int? assetId}) async {
    final response = await _dio.get<List<dynamic>>(
      '/alerts',
      queryParameters: {'asset_id': ?assetId},
    );
    return [
      for (final a in response.data!)
        PriceAlert.fromJson(a as Map<String, dynamic>),
    ];
  }

  Future<PriceAlert> create({
    required int assetId,
    required AlertKind kind,
    required double threshold,
    required bool notifyEmail,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/alerts',
      data: {
        'asset_id': assetId,
        'kind': kind.json,
        // String keeps the exact decimal the user typed.
        'threshold': threshold.toString(),
        'notify_email': notifyEmail,
      },
    );
    return PriceAlert.fromJson(response.data!);
  }

  Future<PriceAlert> setActive(int id, bool active) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/alerts/$id',
      data: {'is_active': active},
    );
    return PriceAlert.fromJson(response.data!);
  }

  Future<void> delete(int id) => _dio.delete<void>('/alerts/$id');
}

final alertsApiProvider = Provider<AlertsApi>(
  (ref) => AlertsApi(ref.watch(dioProvider)),
);

/// Alerts for one asset (or all of the user's alerts when the key is null).
final alertsProvider = FutureProvider.autoDispose
    .family<List<PriceAlert>, int?>(
      (ref, assetId) => ref.watch(alertsApiProvider).list(assetId: assetId),
    );
