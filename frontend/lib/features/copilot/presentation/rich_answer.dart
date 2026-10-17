import 'package:flutter/material.dart';

/// Renders the light markdown small models write: paragraphs, "- " / "* " / "1. " bullets,
/// "#" headings and **bold**. Anything else shows as plain text.
class RichAnswer extends StatelessWidget {
  const RichAnswer(this.text, {super.key});

  final String text;

  static final _bullet = RegExp(r'^\s*(?:[-*•]|\d+[.)])\s+');
  static final _heading = RegExp(r'^\s*#{1,6}\s+');
  static final _bold = RegExp(r'\*\*(.+?)\*\*');

  List<InlineSpan> _inline(String line, TextStyle base) {
    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in _bold.allMatches(line)) {
      if (match.start > start) {
        spans.add(TextSpan(text: line.substring(start, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: base.copyWith(fontWeight: FontWeight.w700),
        ),
      );
      start = match.end;
    }
    if (start < line.length) spans.add(TextSpan(text: line.substring(start)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyLarge!;
    final children = <Widget>[];
    for (final raw in text.trim().split('\n')) {
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
        TextSpan(style: style, children: _inline(content, style)),
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
