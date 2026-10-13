import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/user.dart';

/// Endpoints under /auth. Sign-in calls use the public client; resend needs a signed-in user.
class AuthApi {
  const AuthApi(this._public, this._authed);

  final Dio _public;
  final Dio _authed;

  Future<AuthSession> _session(String path, Map<String, dynamic> body) async {
    final response = await _public.post<Map<String, dynamic>>(path, data: body);
    return AuthSession.fromJson(response.data!);
  }

  Future<AuthSession> register({
    required String email,
    required String password,
    required String fullName,
  }) => _session('/auth/register', {
    'email': email,
    'password': password,
    'full_name': fullName,
  });

  Future<AuthSession> login({
    required String email,
    required String password,
  }) => _session('/auth/login', {'email': email, 'password': password});

  Future<AuthSession> loginWithGoogle(String idToken) =>
      _session('/auth/google', {'id_token': idToken});

  Future<AuthSession> refresh(String refreshToken) =>
      _session('/auth/refresh', {'refresh_token': refreshToken});

  Future<void> logout(String refreshToken) =>
      _public.post<void>('/auth/logout', data: {'refresh_token': refreshToken});

  Future<void> verifyEmail(String token) =>
      _public.post<void>('/auth/verify-email', data: {'token': token});

  Future<String> resendVerification() async {
    final response = await _authed.post<Map<String, dynamic>>(
      '/auth/resend-verification',
    );
    return response.data!['message'] as String;
  }

  Future<String> forgotPassword(String email) async {
    final response = await _public.post<Map<String, dynamic>>(
      '/auth/forgot-password',
      data: {'email': email},
    );
    return response.data!['message'] as String;
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) => _public.post<void>(
    '/auth/reset-password',
    data: {'token': token, 'new_password': newPassword},
  );
}

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(publicDioProvider), ref.watch(dioProvider)),
);
