import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_adviser/core/errors/api_error.dart';
import 'package:stock_adviser/l10n/app_localizations_en.dart';

DioException _error(int status, Object? data) {
  final request = RequestOptions(path: '/x');
  return DioException(
    requestOptions: request,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: request, statusCode: status, data: data),
  );
}

void main() {
  final l10n = AppLocalizationsEn();

  test('framework 404s become a friendly message', () {
    expect(
      apiErrorMessage(_error(404, {'detail': 'Not Found'}), l10n),
      l10n.errorNotAvailable,
    );
    expect(apiErrorMessage(_error(404, null), l10n), l10n.errorNotAvailable);
  });

  test('our API messages are shown as-is', () {
    expect(
      apiErrorMessage(
        _error(404, {'detail': "We couldn't find this asset."}),
        l10n,
      ),
      "We couldn't find this asset.",
    );
    expect(
      apiErrorMessage(
        _error(401, {'detail': 'Invalid email or password'}),
        l10n,
      ),
      'Invalid email or password',
    );
  });

  test('server and network problems', () {
    expect(
      apiErrorMessage(_error(503, {'detail': 'x'}), l10n),
      l10n.errorServer,
    );
    final offline = DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.connectionError,
    );
    expect(apiErrorMessage(offline, l10n), l10n.errorNetwork);
  });
}
