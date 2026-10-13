import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/data/token_store.dart';
import '../../features/auth/domain/user.dart';
import '../config/app_config.dart';

Dio _createDio() => Dio(
  BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ),
);

/// Unauthenticated client: health checks, sign-in endpoints and token refresh.
final publicDioProvider = Provider<Dio>((ref) {
  final dio = _createDio();
  ref.onDispose(dio.close);
  return dio;
});

/// Authenticated client: adds the access token and transparently refreshes it on 401.
final dioProvider = Provider<Dio>((ref) {
  final dio = _createDio();
  dio.interceptors.add(
    _AuthInterceptor(
      dio: dio,
      publicDio: ref.watch(publicDioProvider),
      tokens: ref.watch(tokenStoreProvider),
      onRefreshed: (session) =>
          ref.read(authControllerProvider.notifier).onSessionRefreshed(session),
      onSessionExpired: () =>
          ref.read(authControllerProvider.notifier).onSessionExpired(),
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});

/// Queued so concurrent 401s trigger a single refresh; later ones reuse the new token.
class _AuthInterceptor extends QueuedInterceptor {
  _AuthInterceptor({
    required this.dio,
    required this.publicDio,
    required this.tokens,
    required this.onRefreshed,
    required this.onSessionExpired,
  });

  static const _retriedKey = 'auth_retried';

  final Dio dio;
  final Dio publicDio;
  final TokenStore tokens;
  final void Function(AuthSession session) onRefreshed;
  final Future<void> Function() onSessionExpired;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final access = tokens.accessToken;
    if (access != null) options.headers['Authorization'] = 'Bearer $access';
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    if (err.response?.statusCode != 401 || request.extra[_retriedKey] == true) {
      return handler.next(err);
    }

    // Another queued request may already have refreshed the token.
    final sentWith = request.headers['Authorization'];
    final current = tokens.accessToken;
    final alreadyRefreshed = current != null && sentWith != 'Bearer $current';

    if (!alreadyRefreshed) {
      final refresh = tokens.refreshToken;
      if (refresh == null) return handler.next(err);
      try {
        final response = await publicDio.post<Map<String, dynamic>>(
          '/auth/refresh',
          data: {'refresh_token': refresh},
        );
        final session = AuthSession.fromJson(response.data!);
        await tokens.save(
          access: session.accessToken,
          refresh: session.refreshToken,
        );
        onRefreshed(session);
      } on DioException catch (refreshError) {
        if (refreshError.response?.statusCode == 401) await onSessionExpired();
        return handler.next(err);
      }
    }

    try {
      request.extra[_retriedKey] = true;
      request.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      handler.resolve(await dio.fetch<dynamic>(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}
