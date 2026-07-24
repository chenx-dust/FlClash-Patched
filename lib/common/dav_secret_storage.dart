import 'dart:convert';

import 'package:fl_clash/models/models.dart';
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
      mOptions: MacOsOptions(
        // Data Protection Keychain requires a provisioned signing identity.
        usesDataProtectionKeychain: false,
      ),
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

  Future<DAVProps?> resolve(DAVProps? props) async {
    if (props == null) {
      return null;
    }
    if (props.password.isNotEmpty) {
      await save(props);
      return props;
    }
    final value = await _storage.read(_davSecretKey);
    if (value == null) {
      return props;
    }
    try {
      final secret = jsonDecode(value) as Map<String, dynamic>;
      final matches =
          secret['uri'] == props.uri &&
          secret['user'] == props.user &&
          secret['password'] is String;
      if (!matches) {
        await clear();
        return props;
      }
      return props.copyWith(password: secret['password'] as String);
    } catch (_) {
      await clear();
      return props;
    }
  }

  Future<void> save(DAVProps? props) async {
    if (props == null || props.password.isEmpty) {
      await clear();
      return;
    }
    await _storage.write(
      _davSecretKey,
      jsonEncode({
        'uri': props.uri,
        'user': props.user,
        'password': props.password,
      }),
    );
  }

  Future<void> clear() => _storage.delete(_davSecretKey);
}

const davSecretStorage = DAVSecretStorage(PlatformSecureStorageBackend());
