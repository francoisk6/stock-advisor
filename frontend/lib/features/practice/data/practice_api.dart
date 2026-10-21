import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../../../core/network/api_client.dart';
import '../domain/practice.dart';

class PracticeApi {
  const PracticeApi(this._dio);

  final Dio _dio;

  Future<PracticeAccount> account() async => PracticeAccount.fromJson(
    (await _dio.get<Map<String, dynamic>>('/practice')).data!,
  );

  Future<PracticeAccount> reset() async => PracticeAccount.fromJson(
    (await _dio.post<Map<String, dynamic>>('/practice/reset')).data!,
  );

  Future<PracticeQuote> quote(int assetId) async => PracticeQuote.fromJson(
    (await _dio.get<Map<String, dynamic>>('/practice/quote/$assetId')).data!,
  );

  /// Give [quantity] (units) or [amountUsd] (dollars), not both.
  Future<PracticeOrder> order({
    required int assetId,
    required String side,
    double? quantity,
    double? amountUsd,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/practice/orders',
      data: {
        'asset_id': assetId,
        'side': side,
        if (quantity != null) 'quantity': quantity.toStringAsFixed(8),
        if (amountUsd != null) 'amount_usd': amountUsd.toStringAsFixed(2),
      },
    );
    return PracticeOrder.fromJson(response.data!);
  }

  Future<List<PracticeOrder>> history() async {
    final response = await _dio.get<List<dynamic>>('/practice/orders');
    return [
      for (final o in response.data!)
        PracticeOrder.fromJson(o as Map<String, dynamic>),
    ];
  }

  Future<void> cancel(int orderId) =>
      _dio.delete<void>('/practice/orders/$orderId');

  Future<void> undo(int orderId) =>
      _dio.post<void>('/practice/orders/$orderId/undo');
}

final practiceApiProvider = Provider<PracticeApi>(
  (ref) => PracticeApi(ref.watch(dioProvider)),
);

/// The practice account with live values. Refresh after any trade.
class PracticeController extends AsyncNotifier<PracticeAccount> {
  @override
  Future<PracticeAccount> build() => ref.watch(practiceApiProvider).account();

  Future<PracticeOrder> order({
    required int assetId,
    required String side,
    double? quantity,
    double? amountUsd,
  }) async {
    final placed = await ref
        .read(practiceApiProvider)
        .order(
          assetId: assetId,
          side: side,
          quantity: quantity,
          amountUsd: amountUsd,
        );
    _refresh();
    return placed;
  }

  // A notifier can't invalidate its own provider via ref.invalidate.
  void _refresh() {
    ref.invalidate(practiceHistoryProvider);
    ref.invalidateSelf();
  }

  Future<void> cancel(int orderId) async {
    await ref.read(practiceApiProvider).cancel(orderId);
    _refresh();
  }

  Future<void> reset() async {
    state = AsyncData(await ref.read(practiceApiProvider).reset());
    ref.invalidate(practiceHistoryProvider);
  }
}

/// Reload everything that shows practice data (after trades, undo, fills).
/// Pass `ref.invalidate` (works for Ref and WidgetRef).
void refreshAll(void Function(ProviderOrFamily provider) invalidate) {
  invalidate(practiceProvider);
  invalidate(practiceHistoryProvider);
}

final practiceProvider =
    AsyncNotifierProvider<PracticeController, PracticeAccount>(
      PracticeController.new,
    );

final practiceHistoryProvider = FutureProvider<List<PracticeOrder>>(
  (ref) => ref.watch(practiceApiProvider).history(),
);

final practiceQuoteProvider = FutureProvider.autoDispose
    .family<PracticeQuote, int>(
      (ref, assetId) => ref.watch(practiceApiProvider).quote(assetId),
    );
