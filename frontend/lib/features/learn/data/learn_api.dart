import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/glossary_term.dart';
import '../domain/lesson.dart';

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

  /// Suggested lessons first, with the user's progress.
  Future<List<LessonSummary>> lessons() async {
    final response = await _dio.get<List<dynamic>>('/learn/lessons');
    return [
      for (final l in response.data!)
        LessonSummary.fromJson(l as Map<String, dynamic>),
    ];
  }

  Future<Lesson> lesson(String id) async => Lesson.fromJson(
    (await _dio.get<Map<String, dynamic>>('/learn/lessons/$id')).data!,
  );

  Future<QuizResult> submitQuiz(String id, List<int> answers) async =>
      QuizResult.fromJson(
        (await _dio.post<Map<String, dynamic>>(
          '/learn/lessons/$id/quiz',
          data: {'answers': answers},
        )).data!,
      );
}

final learnApiProvider = Provider<LearnApi>(
  (ref) => LearnApi(ref.watch(dioProvider)),
);

/// The whole glossary (about 65 short entries), loaded once and kept.
final glossaryProvider = FutureProvider<List<GlossaryTerm>>(
  (ref) => ref.watch(learnApiProvider).glossary(),
);

/// Lessons with progress; refreshed after a quiz.
final lessonsProvider = FutureProvider<List<LessonSummary>>(
  (ref) => ref.watch(learnApiProvider).lessons(),
);

final lessonProvider = FutureProvider.family<Lesson, String>(
  (ref, id) => ref.watch(learnApiProvider).lesson(id),
);
