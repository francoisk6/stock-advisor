/// Mirrors the backend `UserOut` schema.
class User {
  const User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.emailVerified,
    required this.hasPassword,
    required this.authProviders,
    required this.createdAt,
    required this.profile,
    required this.plan,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int,
    email: json['email'] as String,
    fullName: json['full_name'] as String,
    emailVerified: json['email_verified'] as bool,
    hasPassword: json['has_password'] as bool,
    authProviders: List<String>.from(json['auth_providers'] as List),
    createdAt: DateTime.parse('${json['created_at']}Z'),
    profile: UserProfile.fromJson(json['profile'] as Map<String, dynamic>),
    plan: Plan.fromJson(json['plan'] as Map<String, dynamic>),
  );

  final int id;
  final String email;
  final String fullName;
  final bool emailVerified;
  final bool hasPassword;
  final List<String> authProviders;
  final DateTime createdAt;
  final UserProfile profile;
  final Plan plan;

  bool get onboardingCompleted => profile.onboardingCompletedAt != null;

  /// First name for friendly greetings; falls back to the email's local part.
  String get displayName {
    final name = fullName.trim();
    if (name.isNotEmpty) return name.split(RegExp(r'\s+')).first;
    return email.split('@').first;
  }
}

class UserProfile {
  const UserProfile({
    required this.experienceLevel,
    required this.riskProfile,
    required this.investmentHorizon,
    required this.assetInterests,
    required this.regionInterests,
    required this.preferredLanguage,
    required this.preferredCurrency,
    required this.onboardingCompletedAt,
    this.digestEmail = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    experienceLevel: json['experience_level'] as String?,
    riskProfile: json['risk_profile'] as String?,
    investmentHorizon: json['investment_horizon'] as String?,
    assetInterests: List<String>.from(json['asset_interests'] as List),
    regionInterests: List<String>.from(json['region_interests'] as List),
    preferredLanguage: json['preferred_language'] as String,
    preferredCurrency: json['preferred_currency'] as String,
    onboardingCompletedAt: json['onboarding_completed_at'] == null
        ? null
        : DateTime.parse('${json['onboarding_completed_at']}Z'),
    digestEmail: json['digest_email'] as bool? ?? false,
  );

  final String? experienceLevel;
  final String? riskProfile;
  final String? investmentHorizon;
  final List<String> assetInterests;
  final List<String> regionInterests;
  final String preferredLanguage;
  final String preferredCurrency;
  final DateTime? onboardingCompletedAt;
  final bool digestEmail;
}

class Plan {
  const Plan({required this.code, required this.name, required this.limits});

  factory Plan.fromJson(Map<String, dynamic> json) => Plan(
    code: json['code'] as String,
    name: json['name'] as String,
    limits: Map<String, dynamic>.from(json['limits'] as Map),
  );

  final String code;
  final String name;
  final Map<String, dynamic> limits;
}

/// Tokens + user returned by every sign-in style endpoint (`AuthOut`).
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    accessToken: json['access_token'] as String,
    refreshToken: json['refresh_token'] as String,
    user: User.fromJson(json['user'] as Map<String, dynamic>),
  );

  final String accessToken;
  final String refreshToken;
  final User user;
}
