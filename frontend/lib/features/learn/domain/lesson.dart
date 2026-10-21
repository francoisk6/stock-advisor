/// A lesson in the list (with the user's progress).
class LessonSummary {
  const LessonSummary({
    required this.id,
    required this.title,
    required this.minutes,
    required this.level,
    required this.summary,
    required this.suggested,
    required this.done,
    required this.bestScore,
    required this.total,
  });

  factory LessonSummary.fromJson(Map<String, dynamic> json) => LessonSummary(
    id: json['id'] as String,
    title: json['title'] as String,
    minutes: json['minutes'] as int,
    level: json['level'] as String,
    summary: json['summary'] as String,
    suggested: json['suggested'] as bool,
    done: json['done'] as bool,
    bestScore: json['best_score'] as int?,
    total: json['total'] as int,
  );

  final String id;
  final String title;
  final int minutes;
  final String level;
  final String summary;
  final bool suggested;
  final bool done;
  final int? bestScore;
  final int total;
}

class LessonSection {
  const LessonSection(this.heading, this.body);

  final String heading;
  final String body;
}

class QuizQuestion {
  const QuizQuestion(this.question, this.options);

  final String question;
  final List<String> options;
}

/// A full lesson. Quiz answers only arrive after submitting ([QuizResult]).
class Lesson {
  const Lesson({
    required this.summary,
    required this.sections,
    required this.terms,
    required this.quiz,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
    summary: LessonSummary.fromJson(json),
    sections: [
      for (final s in json['sections'] as List)
        LessonSection(s['heading'] as String, s['body'] as String),
    ],
    terms: (json['terms'] as List).cast<String>(),
    quiz: [
      for (final q in json['quiz'] as List)
        QuizQuestion(
          q['question'] as String,
          (q['options'] as List).cast<String>(),
        ),
    ],
  );

  final LessonSummary summary;
  final List<LessonSection> sections;
  final List<String> terms; // glossary ids
  final List<QuizQuestion> quiz;
}

class AnswerResult {
  const AnswerResult(this.correct, this.answer, this.explanation);

  final bool correct;
  final int answer;
  final String explanation;
}

class QuizResult {
  const QuizResult({
    required this.score,
    required this.total,
    required this.bestScore,
    required this.results,
  });

  factory QuizResult.fromJson(Map<String, dynamic> json) => QuizResult(
    score: json['score'] as int,
    total: json['total'] as int,
    bestScore: json['best_score'] as int,
    results: [
      for (final r in json['results'] as List)
        AnswerResult(
          r['correct'] as bool,
          r['answer'] as int,
          r['explanation'] as String,
        ),
    ],
  );

  final int score;
  final int total;
  final int bestScore;
  final List<AnswerResult> results;
}
