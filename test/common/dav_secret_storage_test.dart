import 'package:fl_clash/common/common.dart';
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

  test('stores and restores only the password', () async {
    await storage.save('secret');

    expect(await storage.read(), 'secret');
    expect(backend.values.values.single, 'secret');
  });

  test('returns an empty password when storage is empty', () async {
    expect(await storage.read(), isEmpty);
  });

  test('clears the stored password when saving an empty value', () async {
    await storage.save('secret');

    await storage.save('');

    expect(backend.values, isEmpty);
  });

  test('does not hide secure storage write failures', () async {
    backend.failWrites = true;

    expect(storage.save('secret'), throwsStateError);
  });
}
