import 'dart:async';

import '../errors/api_error.dart';

/// Slow server work (briefs, explanations) answers "writing" at once; this checks back until
/// it's "ready" and returns that response. Browsers and proxies drop minute-long requests.
Future<Map<String, dynamic>> pollJob(
  Future<Map<String, dynamic>?> Function() check, {
  required Map<String, dynamic> first,
  Duration every = const Duration(seconds: 3),
  Duration giveUpAfter = const Duration(minutes: 5),
  String tooSlow =
      'This is taking longer than usual. Please try again in a few minutes.',
}) async {
  var current = first;
  final deadline = DateTime.now().add(giveUpAfter);
  while (current['status'] == 'writing') {
    if (DateTime.now().isAfter(deadline)) throw JobFailed(tooSlow);
    await Future<void>.delayed(every);
    current = await check() ?? {'status': 'writing'};
  }
  if (current['status'] == 'failed') {
    throw JobFailed(current['detail'] as String? ?? tooSlow);
  }
  return current;
}
