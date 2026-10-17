import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/domain/user.dart';

/// Answers from the onboarding quiz, as sent to PUT /users/me/profile.
class ProfileAnswers {
  const ProfileAnswers({
    required this.experienceLevel,
    required this.riskProfile,
    required this.investmentHorizon,
    required this.assetInterests,
    required this.regionInterests,
    this.preferredLanguage = 'en',
    this.preferredCurrency = 'USD',
  });

  final String experienceLevel;
  final String riskProfile;
  final String investmentHorizon;
  final List<String> assetInterests;
  final List<String> regionInterests;
  final String preferredLanguage;
  final String preferredCurrency;

  Map<String, dynamic> toJson() => {
    'experience_level': experienceLevel,
    'risk_profile': riskProfile,
    'investment_horizon': investmentHorizon,
    'asset_interests': assetInterests,
    'region_interests': regionInterests,
    'preferred_language': preferredLanguage,
    'preferred_currency': preferredCurrency,
  };
}

class UserApi {
  const UserApi(this._dio);

  final Dio _dio;

  Future<User> me() async {
    final response = await _dio.get<Map<String, dynamic>>('/users/me');
    return User.fromJson(response.data!);
  }

  Future<User> updateName(String fullName) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/users/me',
      data: {'full_name': fullName},
    );
    return User.fromJson(response.data!);
  }

  Future<User> updateProfile(ProfileAnswers answers) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/users/me/profile',
      data: answers.toJson(),
    );
    return User.fromJson(response.data!);
  }

  Future<User> setDigestEmail(bool enabled) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/users/me/preferences',
      data: {'digest_email': enabled},
    );
    return User.fromJson(response.data!);
  }

  /// Returns fresh tokens: the server signs out every other session.
  Future<AuthSession> changePassword({
    String? currentPassword,
    required String newPassword,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/users/me/password',
      data: {'current_password': currentPassword, 'new_password': newPassword},
    );
    return AuthSession.fromJson(response.data!);
  }

  Future<void> deleteAccount({String? password}) =>
      _dio.delete<void>('/users/me', data: {'password': password});
}

final userApiProvider = Provider<UserApi>(
  (ref) => UserApi(ref.watch(dioProvider)),
);
