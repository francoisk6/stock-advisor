import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/poll_job.dart';
import '../domain/market.dart';

class MarketApi {
  const MarketApi(this._dio);

  final Dio _dio;

  Future<List<Asset>> search(String query) async {
    final response = await _dio.get<List<dynamic>>(
      '/assets/search',
      queryParameters: {'q': query},
    );
    return [
      for (final a in response.data!) Asset.fromJson(a as Map<String, dynamic>),
    ];
  }

  /// Curated assets for the user's interests; [type] narrows to one asset type.
  Future<List<Asset>> popular({String? type}) async {
    final response = await _dio.get<List<dynamic>>(
      '/assets/popular',
      queryParameters: {'type': ?type},
    );
    return [
      for (final a in response.data!) Asset.fromJson(a as Map<String, dynamic>),
    ];
  }

  Future<AssetDetail> detail(int id) async {
    final response = await _dio.get<Map<String, dynamic>>('/assets/$id');
    return AssetDetail.fromJson(response.data!);
  }

  Future<List<NewsHeadline>> news(int id) async {
    final response = await _dio.get<List<dynamic>>('/assets/$id/news');
    return [
      for (final n in response.data!)
        NewsHeadline.fromJson(n as Map<String, dynamic>),
    ];
  }

  /// Today's "why did it move?" explanation (writing one takes up to a minute).
  Future<String> whyMoved(int id) async {
    final started = await _dio.post<Map<String, dynamic>>('/assets/$id/why');
    final done = await pollJob(
      () async =>
          (await _dio.get<Map<String, dynamic>?>('/assets/$id/why')).data,
      first: started.data!,
    );
    return done['content'] as String;
  }

  Future<PriceHistory> history(int id, String range) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/assets/$id/history',
      queryParameters: {'range': range},
    );
    return PriceHistory.fromJson(response.data!);
  }
}

final marketApiProvider = Provider<MarketApi>(
  (ref) => MarketApi(ref.watch(dioProvider)),
);

final popularAssetsProvider = FutureProvider.autoDispose
    .family<List<Asset>, String?>(
      (ref, type) => ref.watch(marketApiProvider).popular(type: type),
    );

final assetDetailProvider = FutureProvider.autoDispose.family<AssetDetail, int>(
  (ref, id) => ref.watch(marketApiProvider).detail(id),
);

final assetHistoryProvider = FutureProvider.autoDispose
    .family<PriceHistory, (int, String)>(
      (ref, key) => ref.watch(marketApiProvider).history(key.$1, key.$2),
    );

final assetNewsProvider = FutureProvider.autoDispose
    .family<List<NewsHeadline>, int>(
      (ref, id) => ref.watch(marketApiProvider).news(id),
    );
