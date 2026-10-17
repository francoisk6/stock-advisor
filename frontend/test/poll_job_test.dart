import 'package:flutter_test/flutter_test.dart';
import 'package:stock_adviser/core/errors/api_error.dart';
import 'package:stock_adviser/core/network/poll_job.dart';

void main() {
  test('polls until ready', () async {
    final answers = [
      {'status': 'writing'},
      {'status': 'ready', 'content': 'done'},
    ];
    final result = await pollJob(
      () async => answers.removeAt(0),
      first: {'status': 'writing'},
      every: Duration.zero,
    );
    expect(result['content'], 'done');
  });

  test('failed jobs surface the server message', () async {
    expect(
      () => pollJob(
        () async => {'status': 'failed', 'detail': 'The writer is busy.'},
        first: {'status': 'writing'},
        every: Duration.zero,
      ),
      throwsA(
        isA<JobFailed>().having(
          (e) => e.message,
          'message',
          'The writer is busy.',
        ),
      ),
    );
  });

  test('gives up eventually', () async {
    expect(
      () => pollJob(
        () async => {'status': 'writing'},
        first: {'status': 'writing'},
        every: Duration.zero,
        giveUpAfter: Duration.zero,
      ),
      throwsA(isA<JobFailed>()),
    );
  });
}
