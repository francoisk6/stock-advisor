import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:stock_adviser/features/auth/data/token_store.dart';

/// Like the real web plugin on a plain-http LAN page: reads of missing keys quietly return
/// null, writes throw.
class InsecureContextStorage implements FlutterSecureStorage {
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('only works in secure contexts');
}

void main() {
  test('secure context rule matches browsers', () {
    bool allowed(String url) =>
        browserAllowsSecureStorage(page: Uri.parse(url));
    expect(allowed('http://localhost:8210/'), isTrue);
    expect(allowed('http://127.0.0.1:8210/'), isTrue);
    expect(allowed('https://universal-stock-advisor.com/'), isTrue);
    expect(allowed('http://192.168.150.101:8210/'), isFalse);
  });

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test(
    'falls back to browser storage when secure storage is unavailable',
    () async {
      final store = TokenStore(
        InsecureContextStorage(),
        secureStorageAvailable: false,
      );
      await store
          .load(); // must not throw: the app would hang on the splash screen
      expect(store.refreshToken, isNull);

      await store.save(access: 'a1', refresh: 'r1');

      // A new app start reads the saved session back.
      final restarted = TokenStore(
        InsecureContextStorage(),
        secureStorageAvailable: false,
      );
      await restarted.load();
      expect(restarted.accessToken, 'a1');
      expect(restarted.refreshToken, 'r1');

      await restarted.clear();
      final afterLogout = TokenStore(
        InsecureContextStorage(),
        secureStorageAvailable: false,
      );
      await afterLogout.load();
      expect(afterLogout.refreshToken, isNull);
      expect(await SharedPreferencesAsync().getString('refresh_token'), isNull);
    },
  );
}
