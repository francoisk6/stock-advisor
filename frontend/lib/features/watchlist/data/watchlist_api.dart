import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../market/domain/market.dart';

class Watchlist {
  const Watchlist({
    required this.name,
    required this.limit,
    required this.items,
  });

  factory Watchlist.fromJson(Map<String, dynamic> json) => Watchlist(
    name: json['name'] as String,
    limit: json['limit'] as int?,
    items: [
      for (final a in json['items'] as List)
        Asset.fromJson(a as Map<String, dynamic>),
    ],
  );

  final String name;
  final int? limit;
  final List<Asset> items;

  bool contains(int assetId) => items.any((a) => a.id == assetId);
}

class WatchlistApi {
  const WatchlistApi(this._dio);

  final Dio _dio;

  Future<Watchlist> get() async => Watchlist.fromJson(
    (await _dio.get<Map<String, dynamic>>('/watchlist')).data!,
  );

  Future<Watchlist> add(int assetId) async => Watchlist.fromJson(
    (await _dio.put<Map<String, dynamic>>('/watchlist/assets/$assetId')).data!,
  );

  Future<Watchlist> remove(int assetId) async => Watchlist.fromJson(
    (await _dio.delete<Map<String, dynamic>>(
      '/watchlist/assets/$assetId',
    )).data!,
  );
}

final watchlistApiProvider = Provider<WatchlistApi>(
  (ref) => WatchlistApi(ref.watch(dioProvider)),
);

/// The user's watchlist; add/remove update it in place for every screen.
class WatchlistController extends AsyncNotifier<Watchlist> {
  @override
  Future<Watchlist> build() => ref.watch(watchlistApiProvider).get();

  Future<void> add(int assetId) async =>
      state = AsyncData(await ref.read(watchlistApiProvider).add(assetId));

  Future<void> remove(int assetId) async =>
      state = AsyncData(await ref.read(watchlistApiProvider).remove(assetId));
}

final watchlistProvider = AsyncNotifierProvider<WatchlistController, Watchlist>(
  WatchlistController.new,
);
