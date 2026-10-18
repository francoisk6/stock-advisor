/// One glossary entry (served by the backend so the app and the copilot use the same text).
class GlossaryTerm {
  const GlossaryTerm({
    required this.id,
    required this.term,
    required this.aliases,
    required this.category,
    required this.short,
    required this.body,
    required this.example,
    required this.related,
  });

  factory GlossaryTerm.fromJson(Map<String, dynamic> json) => GlossaryTerm(
    id: json['id'] as String,
    term: json['term'] as String,
    aliases: (json['aliases'] as List).cast<String>(),
    category: json['category'] as String,
    short: json['short'] as String,
    body: json['body'] as String,
    example: json['example'] as String?,
    related: (json['related'] as List).cast<String>(),
  );

  final String id;
  final String term;
  final List<String> aliases;
  final String category;
  final String short;
  final String body;
  final String? example;
  final List<String> related;

  /// Case-insensitive match on the name, aliases and one-line summary.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return term.toLowerCase().contains(q) ||
        short.toLowerCase().contains(q) ||
        aliases.any((a) => a.toLowerCase().contains(q));
  }
}
