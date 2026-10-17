import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/open_link.dart';

/// Renders the light markdown small models write: paragraphs, "- " / "* " / "1. " bullets,
/// "#" headings, **bold** and [source](https://…) links. While an answer streams, citations
/// look like [Reuters](n1); those show as plain text until the real link arrives.
class RichAnswer extends StatefulWidget {
  const RichAnswer(this.text, {super.key});

  final String text;

  @override
  State<RichAnswer> createState() => _RichAnswerState();
}

class _RichAnswerState extends State<RichAnswer> {
  static final _bullet = RegExp(r'^\s*(?:[-*•]|\d+[.)])\s+');
  static final _heading = RegExp(r'^\s*#{1,6}\s+');
  static final _inline = RegExp(
    r'\*\*(.+?)\*\*|\[([^\]\n]+)\]\((https?://[^)\s]+)\)|\[([^\]\n]+)\]\([a-z]\d+\)',
  );

  final _recognizers = <TapGestureRecognizer>[];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  List<InlineSpan> _spans(String line, TextStyle base, Color linkColor) {
    final spans = <InlineSpan>[];
    var start = 0;
    for (final m in _inline.allMatches(line)) {
      if (m.start > start) {
        spans.add(TextSpan(text: line.substring(start, m.start)));
      }
      if (m.group(1) != null) {
        spans.add(
          TextSpan(
            text: m.group(1),
            style: base.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      } else if (m.group(2) != null) {
        final url = m.group(3)!;
        final recognizer = TapGestureRecognizer()..onTap = () => openLink(url);
        _recognizers.add(recognizer);
        spans.add(
          TextSpan(
            text: m.group(2),
            style: base.copyWith(
              color: linkColor,
              decoration: TextDecoration.underline,
            ),
            recognizer: recognizer,
            semanticsLabel: m.group(2),
          ),
        );
      } else {
        spans.add(TextSpan(text: m.group(4)));
      }
      start = m.end;
    }
    if (start < line.length) spans.add(TextSpan(text: line.substring(start)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyLarge!;
    final children = <Widget>[];
    for (final raw in widget.text.trim().split('\n')) {
      if (raw.trim().isEmpty) {
        children.add(const SizedBox(height: 8));
        continue;
      }
      final bullet = _bullet.firstMatch(raw);
      final heading = _heading.firstMatch(raw);
      final content = raw
          .replaceFirst(_bullet, '')
          .replaceFirst(_heading, '')
          .replaceAll('__', '');
      final style = heading != null
          ? base.copyWith(fontWeight: FontWeight.w700)
          : base;
      final line = Text.rich(
        TextSpan(
          style: style,
          children: _spans(content, style, theme.colorScheme.primary),
        ),
      );
      children.add(
        bullet == null
            ? line
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 4, end: 8),
                    child: Text('•', style: base),
                  ),
                  Expanded(child: line),
                ],
              ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
