import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/glossary_term.dart';

class LearnApi {
  const LearnApi(this._dio);

  final Dio _dio;

  Future<List<GlossaryTerm>> glossary() async {
    final response = await _dio.get<List<dynamic>>('/learn/glossary');
    return [
      for (final t in response.data!)
        GlossaryTerm.fromJson(t as Map<String, dynamic>),
    ];
  }
}

final learnApiProvider = Provider<LearnApi>(
  (ref) => LearnApi(ref.watch(dioProvider)),
);

/// The whole glossary (about 65 short entries), loaded once and kept.
final glossaryProvider = FutureProvider<List<GlossaryTerm>>(
  (ref) => ref.watch(learnApiProvider).glossary(),
);
