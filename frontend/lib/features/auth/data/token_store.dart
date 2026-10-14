import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps tokens in memory for requests and persists them so sessions survive restarts.
///
/// Uses encrypted secure storage. Browsers only allow that on HTTPS or localhost; on a plain
/// `http://<LAN IP>` dev page it throws, so we fall back to ordinary browser storage there.
/// Production is served over HTTPS and always uses secure storage.
class TokenStore {
  TokenStore(
    this._secure, {
    SharedPreferencesAsync? fallback,
    bool? secureStorageAvailable,
  }) : _fallbackStorage = fallback,
       // Decided up front: on an insecure page secure storage still *reads* without error
       // (it just finds nothing), so failures alone can't tell us to use the fallback.
       _useFallback = !(secureStorageAvailable ?? browserAllowsSecureStorage());

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  final FlutterSecureStorage _secure;
  SharedPreferencesAsync? _fallbackStorage;
  bool _useFallback;

  String? accessToken;
  String? refreshToken;

  SharedPreferencesAsync get _fallback =>
      _fallbackStorage ??= SharedPreferencesAsync();

  Future<String?> _read(String key) async {
    if (!_useFallback) {
      try {
        return await _secure.read(key: key);
      } catch (_) {
        _useFallback = true; // insecure context (or broken storage)
      }
    }
    return _fallback.getString(key);
  }

  Future<void> _write(String key, String value) async {
    if (!_useFallback) {
      try {
        return await _secure.write(key: key, value: value);
      } catch (_) {
        _useFallback = true;
      }
    }
    await _fallback.setString(key, value);
  }

  Future<void> _delete(String key) async {
    if (!_useFallback) {
      try {
        return await _secure.delete(key: key);
      } catch (_) {
        _useFallback = true;
      }
    }
    await _fallback.remove(key);
  }

  Future<void> load() async {
    try {
      accessToken = await _read(_accessKey);
      refreshToken = await _read(_refreshKey);
    } catch (_) {
      // Unreadable storage: start signed out.
      await clear();
    }
  }

  Future<void> save({required String access, required String refresh}) async {
    accessToken = access;
    refreshToken = refresh;
    try {
      await _write(_accessKey, access);
      await _write(_refreshKey, refresh);
    } catch (_) {
      // Can't persist: this session still works until the app is closed.
    }
  }

  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    try {
      await _delete(_accessKey);
      await _delete(_refreshKey);
    } catch (_) {
      // Nothing more we can do; in-memory tokens are already gone.
    }
  }
}

/// The browser's "secure context" rule: HTTPS, or localhost over plain HTTP.
bool browserAllowsSecureStorage({Uri? page}) {
  if (!kIsWeb && page == null) return true;
  final uri = page ?? Uri.base;
  const localHosts = {'localhost', '127.0.0.1', '::1', '[::1]'};
  return uri.scheme == 'https' ||
      localHosts.contains(uri.host) ||
      uri.host.endsWith('.localhost');
}

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => TokenStore(const FlutterSecureStorage()),
);
