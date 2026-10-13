import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class HealthStatus {
  const HealthStatus({required this.status, required this.environment});

  factory HealthStatus.fromJson(Map<String, dynamic> json) => HealthStatus(
        status: json['status'] as String,
        environment: json['environment'] as String,
      );

  final String status;
  final String environment;
}

class HealthRepository {
  const HealthRepository(this._dio);

  final Dio _dio;

  Future<HealthStatus> fetch() async {
    final response = await _dio.get<Map<String, dynamic>>('/health');
    return HealthStatus.fromJson(response.data!);
  }
}

final healthRepositoryProvider = Provider<HealthRepository>(
  (ref) => HealthRepository(ref.watch(dioProvider)),
);

final healthStatusProvider = FutureProvider.autoDispose<HealthStatus>(
  (ref) => ref.watch(healthRepositoryProvider).fetch(),
);
