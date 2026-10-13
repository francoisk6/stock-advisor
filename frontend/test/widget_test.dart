import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_adviser/app.dart';
import 'package:stock_adviser/features/health/data/health_repository.dart';

void main() {
  testWidgets('home shows welcome, disclaimer and server status', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          healthStatusProvider.overrideWith(
            (ref) async => const HealthStatus(status: 'ok', environment: 'test'),
          ),
        ],
        child: const StockAdviserApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to your AI market copilot'), findsOneWidget);
    expect(find.text('Educational information only — not financial advice.'), findsOneWidget);
    expect(find.text('Connected (test)'), findsOneWidget);
  });
}
