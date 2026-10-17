import 'package:dio/dio.dart';

import '../../l10n/app_localizations.dart';

/// A server-side job (brief, explanation) finished with a friendly error message.
class JobFailed implements Exception {
  const JobFailed(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Turns any error from an API call into a short message a beginner can act on.
String apiErrorMessage(Object error, AppLocalizations l10n) {
  if (error is JobFailed) return error.message;
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
  // The framework's own "Not Found"/"Method Not Allowed" (missing route, outdated server)
  // is not written for users; our API's own errors are.
  if ((status == 404 || status == 405) && _frameworkDetails.contains(detail)) {
    return l10n.errorNotAvailable;
  }
  if (status == 422) return l10n.errorValidation;
  if (status == 429) return detail ?? l10n.errorTooManyAttempts;
  if (status != null && status >= 500) return l10n.errorServer;
  return detail ?? l10n.errorUnexpected;
}

const _frameworkDetails = {null, 'Not Found', 'Method Not Allowed'};

String? _detail(Object? data) {
  if (data is Map && data['detail'] is String) return data['detail'] as String;
  return null;
}
