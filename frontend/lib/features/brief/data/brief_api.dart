import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/poll_job.dart';

class Brief {
  const Brief({required this.content, required this.createdAt});

  factory Brief.fromJson(Map<String, dynamic> json) => Brief(
    content: json['content'] as String,
    createdAt: DateTime.parse('${json['created_at']}Z'),
  );

  final String content;
  final DateTime createdAt;
}

class BriefApi {
  const BriefApi(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>?> _status() async =>
      (await _dio.get<Map<String, dynamic>?>('/digest/today')).data;

  /// Today's brief; if it's being written right now, waits for it.
  Future<Brief?> today() async {
    final status = await _status();
    if (status == null) return null;
    return Brief.fromJson(await pollJob(_status, first: status));
  }

  /// Writes today's brief if there isn't one yet (about a minute on our server).
  Future<Brief> create() async {
    final started = await _dio.post<Map<String, dynamic>>('/digest/today');
    return Brief.fromJson(await pollJob(_status, first: started.data!));
  }
}

final briefApiProvider = Provider<BriefApi>(
  (ref) => BriefApi(ref.watch(dioProvider)),
);

/// Today's brief, or null. `create()` replaces it in place.
class BriefController extends AsyncNotifier<Brief?> {
  @override
  Future<Brief?> build() => ref.watch(briefApiProvider).today();

  Future<void> create() async {
    state = const AsyncLoading<Brief?>();
    state = await AsyncValue.guard(() => ref.read(briefApiProvider).create());
  }
}

final briefProvider = AsyncNotifierProvider<BriefController, Brief?>(
  BriefController.new,
);
