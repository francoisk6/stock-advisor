import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps tokens in memory for requests and persists them so sessions survive restarts.
class TokenStore {
  TokenStore(this._storage);

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  final FlutterSecureStorage _storage;

  String? accessToken;
  String? refreshToken;

  Future<void> load() async {
    try {
      accessToken = await _storage.read(key: _accessKey);
      refreshToken = await _storage.read(key: _refreshKey);
    } on Exception {
      // Corrupted or unavailable storage: start signed out.
      await clear();
    }
  }

  Future<void> save({required String access, required String refresh}) async {
    accessToken = access;
    refreshToken = refresh;
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    try {
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
    } on Exception {
      // Nothing more we can do; in-memory tokens are already gone.
    }
  }
}

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => TokenStore(const FlutterSecureStorage()),
);
