import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_error.dart';
import '../../../core/widgets/busy_button.dart';
import '../../../core/widgets/error_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../copilot/presentation/rich_answer.dart';
import '../../market/presentation/widgets/price_change.dart';
import '../data/learn_api.dart';
import '../domain/lesson.dart';

/// One lesson: short sections, the glossary words it uses, and a 3-question quiz.
class LessonScreen extends ConsumerWidget {
  const LessonScreen({super.key, required this.lessonId});

  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lesson = ref.watch(lessonProvider(lessonId));
    final glossary = ref.watch(glossaryProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navLearn)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: lesson.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: ErrorText(apiErrorMessage(e, l10n)),
            ),
            data: (x) {
              final names = {for (final t in glossary) t.id: t.term};
              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                children: [
                  Semantics(
                    header: true,
                    container: true,
                    child: Text(
                      x.summary.title,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.lessonMinutes(x.summary.minutes),
                    style: theme.textTheme.bodySmall,
                  ),
                  for (final s in x.sections) ...[
                    const SizedBox(height: 20),
                    Semantics(
                      header: true,
                      container: true,
                      child: Text(
                        s.heading,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 6),
                    RichAnswer(s.body),
                  ],
                  if (x.terms.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Semantics(
                      header: true,
                      container: true,
                      child: Text(
                        l10n.lessonKeyTerms,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final id in x.terms)
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => context.go('/learn/$id'),
                            child: Text(names[id] ?? id),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 32),
                  _Quiz(lessonId: lessonId, lesson: x),
                  const SizedBox(height: 16),
                  Text(l10n.lessonNote, style: theme.textTheme.bodySmall),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Quiz extends ConsumerStatefulWidget {
  const _Quiz({required this.lessonId, required this.lesson});

  final String lessonId;
  final Lesson lesson;

  @override
  ConsumerState<_Quiz> createState() => _QuizState();
}

class _QuizState extends ConsumerState<_Quiz> {
  late List<int?> _answers = List.filled(widget.lesson.quiz.length, null);
  QuizResult? _result;
  bool _busy = false;
  String? _error;

  Future<void> _check() async {
    final l10n = AppLocalizations.of(context);
    if (_answers.contains(null)) {
      setState(() => _error = l10n.quizAnswerAll(_answers.length));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(learnApiProvider)
          .submitQuiz(widget.lessonId, _answers.cast<int>());
      ref.invalidate(lessonsProvider); // progress shows in the list
      setState(() {
        _result = result;
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = apiErrorMessage(e, l10n);
      });
    }
  }

  void _retry() => setState(() {
    _answers = List.filled(widget.lesson.quiz.length, null);
    _result = null;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final result = _result;
    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              container: true,
              child: Text(l10n.quizTitle, style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: 4),
            Text(l10n.quizIntro, style: theme.textTheme.bodySmall),
            for (final (i, q) in widget.lesson.quiz.indexed) ...[
              const SizedBox(height: 16),
              Text(
                '${i + 1}. ${q.question}',
                style: theme.textTheme.titleSmall,
              ),
              RadioGroup<int>(
                groupValue: _answers[i],
                onChanged: (v) {
                  if (result == null) setState(() => _answers[i] = v);
                },
                child: Column(
                  children: [
                    for (final (j, option) in q.options.indexed)
                      RadioListTile<int>(
                        value: j,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        enabled: result == null,
                        title: Text(option),
                      ),
                  ],
                ),
              ),
              if (result != null) _Feedback(result.results[i], q),
            ],
            const SizedBox(height: 16),
            if (result == null) ...[
              ErrorText(_error),
              BusyButton(busy: _busy, onPressed: _check, label: l10n.quizCheck),
            ] else ...[
              Text(
                l10n.quizScore(result.score, result.total),
                style: theme.textTheme.titleMedium,
              ),
              Text(
                l10n.quizBest(result.bestScore, result.total),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton(
                  onPressed: _retry,
                  child: Text(l10n.quizRetry),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Right/wrong with icon + word (never colour alone), then the explanation.
class _Feedback extends StatelessWidget {
  const _Feedback(this.result, this.question);

  final AnswerResult result;
  final QuizQuestion question;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = changeColor(context, result.correct ? 1 : -1);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(result.correct ? Icons.check_circle : Icons.cancel, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.correct
                    ? l10n.quizRight
                    : l10n.quizWrong(question.options[result.answer]),
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
              Text(result.explanation),
            ],
          ),
        ),
      ],
    );
  }
}
