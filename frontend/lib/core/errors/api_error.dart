import 'package:dio/dio.dart';

import '../../l10n/app_localizations.dart';

/// Turns any error from an API call into a short message a beginner can act on.
String apiErrorMessage(Object error, AppLocalizations l10n) {
  if (error is! DioException) return l10n.errorUnexpected;

  switch (error.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.sendTimeout:
      return l10n.errorNetwork;
    default:
      break;
  }

  final status = error.response?.statusCode;
  final detail = _detail(error.response?.data);
  if (status == 422) return l10n.errorValidation;
  if (status == 429) return detail ?? l10n.errorTooManyAttempts;
  if (status != null && status >= 500) return l10n.errorServer;
  return detail ?? l10n.errorUnexpected;
}

String? _detail(Object? data) {
  if (data is Map && data['detail'] is String) return data['detail'] as String;
  return null;
}
