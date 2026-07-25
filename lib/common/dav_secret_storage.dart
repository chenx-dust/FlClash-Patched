import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _davSecretKey = 'webdav_credentials';

abstract interface class SecureStorageBackend {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class PlatformSecureStorageBackend implements SecureStorageBackend {
  final FlutterSecureStorage _storage;

  const PlatformSecureStorageBackend([
    this._storage = const FlutterSecureStorage(
      mOptions: MacOsOptions(usesDataProtectionKeychain: false),
    ),
  ]);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class DAVSecretStorage {
  final SecureStorageBackend _storage;

  const DAVSecretStorage(this._storage);

  Future<String> read() async => await _storage.read(_davSecretKey) ?? '';

  Future<void> save(String password) {
    if (password.isEmpty) {
      return clear();
    }
    return _storage.write(_davSecretKey, password);
  }

  Future<void> clear() => _storage.delete(_davSecretKey);
}

const davSecretStorage = DAVSecretStorage(PlatformSecureStorageBackend());
