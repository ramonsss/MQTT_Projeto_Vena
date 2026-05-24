import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureTokenStorage {
  const SecureTokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _kAccess = 'vena_access_token';
  static const _kRefresh = 'vena_refresh_token';
  static const _kMqtt = 'vena_mqtt_token';

  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    await Future.wait([
      _storage.write(key: _kAccess, value: access),
      _storage.write(key: _kRefresh, value: refresh),
    ]);
  }

  Future<String?> getAccessToken() => _storage.read(key: _kAccess);
  Future<String?> getRefreshToken() => _storage.read(key: _kRefresh);

  Future<void> saveMqttToken(String token) =>
      _storage.write(key: _kMqtt, value: token);
  Future<String?> getMqttToken() => _storage.read(key: _kMqtt);

  Future<void> clear() => _storage.deleteAll();
}

final secureTokenStorageProvider = Provider<SecureTokenStorage>((ref) {
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  return SecureTokenStorage(storage);
});
