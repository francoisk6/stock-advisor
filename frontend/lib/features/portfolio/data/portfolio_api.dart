import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/application/auth_controller.dart';
import '../domain/portfolio.dart';

String? _date(DateTime? d) => d == null
    ? null
    : '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class PortfolioApi {
  const PortfolioApi(this._dio);

  final Dio _dio;

  Portfolio _parse(Response<Map<String, dynamic>> r) =>
      Portfolio.fromJson(r.data!);

  Future<Portfolio> get() async =>
      _parse(await _dio.get<Map<String, dynamic>>('/portfolio'));

  Map<String, dynamic> _body(
    double quantity,
    double averagePrice,
    DateTime? boughtOn,
    String? note,
  ) => {
    'quantity': quantity.toStringAsFixed(8),
    'average_price': averagePrice.toStringAsFixed(8),
    'bought_on': _date(boughtOn),
    'note': (note == null || note.trim().isEmpty) ? null : note.trim(),
  };

  Future<Portfolio> add({
    required int assetId,
    required double quantity,
    required double averagePrice,
    DateTime? boughtOn,
    String? note,
  }) async => _parse(
    await _dio.post<Map<String, dynamic>>(
      '/portfolio/holdings',
      data: {
        'asset_id': assetId,
        ..._body(quantity, averagePrice, boughtOn, note),
      },
    ),
  );

  Future<Portfolio> update(
    int holdingId, {
    required double quantity,
    required double averagePrice,
    DateTime? boughtOn,
    String? note,
  }) async => _parse(
    await _dio.put<Map<String, dynamic>>(
      '/portfolio/holdings/$holdingId',
      data: _body(quantity, averagePrice, boughtOn, note),
    ),
  );

  Future<void> delete(int holdingId) =>
      _dio.delete<void>('/portfolio/holdings/$holdingId');

  Future<Portfolio> setCurrency(String currency) async => _parse(
    await _dio.put<Map<String, dynamic>>(
      '/portfolio/currency',
      data: {'currency': currency},
    ),
  );
}

final portfolioApiProvider = Provider<PortfolioApi>(
  (ref) => PortfolioApi(ref.watch(dioProvider)),
);

/// The user's portfolio; every change returns the new summary, which replaces the state.
class PortfolioController extends AsyncNotifier<Portfolio> {
  PortfolioApi get _api => ref.read(portfolioApiProvider);

  @override
  Future<Portfolio> build() => ref.watch(portfolioApiProvider).get();

  Future<void> add({
    required int assetId,
    required double quantity,
    required double averagePrice,
    DateTime? boughtOn,
    String? note,
  }) async => state = AsyncData(
    await _api.add(
      assetId: assetId,
      quantity: quantity,
      averagePrice: averagePrice,
      boughtOn: boughtOn,
      note: note,
    ),
  );

  Future<void> edit(
    int holdingId, {
    required double quantity,
    required double averagePrice,
    DateTime? boughtOn,
    String? note,
  }) async => state = AsyncData(
    await _api.update(
      holdingId,
      quantity: quantity,
      averagePrice: averagePrice,
      boughtOn: boughtOn,
      note: note,
    ),
  );

  Future<void> remove(int holdingId) async {
    await _api.delete(holdingId);
    ref.invalidateSelf();
  }

  /// Also the profile's preferred currency: reload the user so later profile edits keep it.
  Future<void> setCurrency(String currency) async {
    state = AsyncData(await _api.setCurrency(currency));
    await ref.read(authControllerProvider.notifier).reloadUser();
  }
}

final portfolioProvider = AsyncNotifierProvider<PortfolioController, Portfolio>(
  PortfolioController.new,
);
