import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemorySecureStorage implements SecureStorageBackend {
  final values = <String, String>{};
  bool failWrites = false;

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) {
      throw StateError('secure storage unavailable');
    }
    values[key] = value;
  }
}

void main() {
  late _MemorySecureStorage backend;
  late DAVSecretStorage storage;

  setUp(() {
    backend = _MemorySecureStorage();
    storage = DAVSecretStorage(backend);
  });

  test('stores and restores a password for the same DAV identity', () async {
    const props = DAVProps(
      uri: 'https://dav.example.com',
      user: 'user',
      password: 'secret',
    );

    await storage.save(props);
    final restored = await storage.resolve(props.copyWith(password: ''));

    expect(restored, props);
    expect(
      backend.values.values.single,
      jsonEncode({
        'uri': props.uri,
        'user': props.user,
        'password': props.password,
      }),
    );
  });

  test('migrates a legacy plaintext password into secure storage', () async {
    const props = DAVProps(
      uri: 'https://dav.example.com',
      user: 'user',
      password: 'legacy-secret',
    );

    final restored = await storage.resolve(props);

    expect(restored, props);
    expect(backend.values, isNotEmpty);
  });

  test('does not reuse a password for a different DAV identity', () async {
    const props = DAVProps(
      uri: 'https://dav.example.com',
      user: 'user',
      password: 'secret',
    );
    await storage.save(props);

    final restored = await storage.resolve(
      const DAVProps(uri: 'https://other.example.com', user: 'user'),
    );

    expect(restored?.password, isEmpty);
    expect(backend.values, isEmpty);
  });

  test('does not hide secure storage write failures', () async {
    backend.failWrites = true;

    expect(
      storage.save(
        const DAVProps(
          uri: 'https://dav.example.com',
          user: 'user',
          password: 'secret',
        ),
      ),
      throwsStateError,
    );
  });

  test('does not access secure storage when DAV is not configured', () async {
    backend.failWrites = true;

    expect(await storage.resolve(null), null);
  });
}
