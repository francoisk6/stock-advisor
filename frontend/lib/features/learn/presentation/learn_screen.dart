import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_error.dart';
import '../../../core/widgets/error_text.dart';
import '../../../l10n/app_localizations.dart';
import '../data/learn_api.dart';
import '../domain/lesson.dart';

/// The Learn tab: suggested lessons, the rest, and the glossary.
class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lessons = ref.watch(lessonsProvider);

    Widget header(String text) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Semantics(
        header: true,
        container: true,
        child: Text(text, style: theme.textTheme.titleMedium),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navLearn)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(lessonsProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(l10n.learnIntro),
                const SizedBox(height: 12),
                Card(
                  color: theme.colorScheme.surfaceContainerLow,
                  child: ListTile(
                    leading: const Icon(Icons.menu_book_outlined),
                    title: Text(l10n.glossaryOpen),
                    subtitle: Text(l10n.glossaryOpenHint),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/learn/glossary'),
                  ),
                ),
                ...lessons.when(
                  loading: () => [
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                  error: (e, _) => [ErrorText(apiErrorMessage(e, l10n))],
                  data: (all) {
                    final mine = all.where((x) => x.suggested).toList();
                    final rest = all.where((x) => !x.suggested).toList();
                    return [
                      header(l10n.lessonsForYou),
                      if (mine.isEmpty) Text(l10n.lessonsAllDone),
                      for (final x in mine) _LessonTile(lesson: x),
                      if (rest.isNotEmpty) header(l10n.lessonsMore),
                      for (final x in rest) _LessonTile(lesson: x),
                    ];
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.lesson});

  final LessonSummary lesson;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final x = lesson;
    final meta = [
      l10n.lessonMinutes(x.minutes),
      if (x.level == 'intermediate') l10n.levelIntermediate,
      if (x.done) l10n.lessonDone(x.bestScore ?? 0, x.total),
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        x.done ? Icons.check_circle : Icons.school_outlined,
        color: x.done ? theme.colorScheme.primary : null,
      ),
      title: Text(x.title),
      subtitle: Text('${x.summary}\n$meta'),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.go('/learn/lessons/${x.id}'),
    );
  }
}
