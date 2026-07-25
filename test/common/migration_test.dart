import 'dart:convert';

import 'package:fl_clash/common/migration.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Migration', () {
    test('returns current config without rewriting storage', () async {
      final configMap = _createConfigMap();
      final store = _FakeMigrationStore(
        configMap: configMap,
        version: Migration.currentVersion,
      );

      final config = await Migration(store: store).run();

      expect(config, Config.realFromJson(configMap));
      expect(store.events, ['getConfigMap', 'getVersion']);
    });

    test(
      'moves a compatible DAV password without a version migration',
      () async {
        final configMap = _createConfigMap(
          davProps: const DAVProps(
            uri: 'https://example.com/dav',
            user: 'user',
          ),
        );
        final davProps = configMap['davProps']! as Map<String, Object?>;
        davProps['password'] = 'secret';
        final store = _FakeMigrationStore(configMap: configMap, version: 1);

        final config = await Migration(store: store).run();

        expect(config.davProps?.user, 'user');
        expect(store.savedDavPassword, 'secret');
        expect(store.savedConfig, config);
        expect(store.version, Migration.currentVersion);
        expect(store.events, [
          'getConfigMap',
          'getVersion',
          'saveDavPassword',
          'saveConfig',
        ]);
      },
    );

    test(
      'commits v0 cleanup and version only after migrated data is saved',
      () async {
        final configMap = <String, Object?>{
          'proxiesStyle': <String, Object?>{},
          'dav': <String, Object?>{
            'uri': 'https://example.com/dav',
            'user': 'user',
            'password': 'secret',
          },
        };
        final store = _FakeMigrationStore(
          configMap: configMap,
          version: 0,
          clashConfigMap: <String, Object?>{'mixed-port': 7890},
        );
        final migration = Migration(
          store: store,
          migrateV0: (configMap) async {
            store.events.add('migrateV0');
            expect(configMap['patchClashConfig'], store.clashConfigMap);
            return MigrationData(
              configMap: _createConfigMap(
                davProps: const DAVProps(
                  uri: 'https://example.com/dav',
                  user: 'user',
                ),
              ),
            );
          },
        );

        await migration.run();

        expect(store.events, [
          'getConfigMap',
          'getVersion',
          'saveDavPassword',
          'getClashConfigMap',
          'migrateV0',
          'restore',
          'saveConfig',
          'clearClashConfig',
          'setVersion',
        ]);
        expect(store.savedDavPassword, 'secret');
        expect(store.didClearClashConfig, isTrue);
        expect(store.version, Migration.currentVersion);
      },
    );

    test(
      'does not mutate other storage when saving the password fails',
      () async {
        final configMap = _createConfigMap(
          davProps: const DAVProps(
            uri: 'https://example.com/dav',
            user: 'user',
          ),
        );
        final davProps = configMap['davProps']! as Map<String, Object?>;
        davProps['password'] = 'secret';
        final store = _FakeMigrationStore(
          configMap: configMap,
          version: 1,
          failDavPasswordSave: true,
        );

        await expectLater(
          Migration(store: store).run(),
          throwsA(isA<StateError>()),
        );

        expect(store.events, ['getConfigMap', 'getVersion', 'saveDavPassword']);
        expect(store.savedConfig, isNull);
        expect(store.version, 1);
      },
    );

    test('keeps the current version when DAV config cleanup fails', () async {
      final configMap = _createConfigMap(
        davProps: const DAVProps(uri: 'https://example.com/dav', user: 'user'),
      );
      final davProps = configMap['davProps']! as Map<String, Object?>;
      davProps['password'] = 'secret';
      final store = _FakeMigrationStore(
        configMap: configMap,
        version: Migration.currentVersion,
        configSaveResult: false,
      );

      await expectLater(
        Migration(store: store).run(),
        throwsA(isA<StateError>()),
      );

      expect(store.events, [
        'getConfigMap',
        'getVersion',
        'saveDavPassword',
        'saveConfig',
      ]);
      expect(store.version, Migration.currentVersion);
    });
  });
}

Map<String, Object?> _createConfigMap({DAVProps? davProps}) {
  return jsonDecode(
        jsonEncode(Config(themeProps: defaultThemeProps, davProps: davProps)),
      )
      as Map<String, Object?>;
}

class _FakeMigrationStore implements MigrationStore {
  final Map<String, Object?>? configMap;
  final Map<String, Object?>? clashConfigMap;
  final bool failDavPasswordSave;
  final bool configSaveResult;
  final List<String> events = [];

  int version;
  String? savedDavPassword;
  Config? savedConfig;
  MigrationData? restoredData;
  bool didClearClashConfig = false;

  _FakeMigrationStore({
    required this.configMap,
    required this.version,
    this.clashConfigMap,
    this.failDavPasswordSave = false,
    this.configSaveResult = true,
  });

  @override
  Future<void> clearClashConfig() async {
    events.add('clearClashConfig');
    didClearClashConfig = true;
  }

  @override
  Future<Map<String, Object?>?> getClashConfigMap() async {
    events.add('getClashConfigMap');
    return clashConfigMap;
  }

  @override
  Future<Map<String, Object?>?> getConfigMap() async {
    events.add('getConfigMap');
    return configMap;
  }

  @override
  Future<int> getVersion() async {
    events.add('getVersion');
    return version;
  }

  @override
  Future<void> restore(MigrationData data) async {
    events.add('restore');
    restoredData = data;
  }

  @override
  Future<bool> saveConfig(Config config) async {
    events.add('saveConfig');
    savedConfig = config;
    return configSaveResult;
  }

  @override
  Future<void> saveDavPassword(String password) async {
    events.add('saveDavPassword');
    if (failDavPasswordSave) {
      throw StateError('Failed to save DAV password');
    }
    savedDavPassword = password;
  }

  @override
  Future<void> setVersion(int version) async {
    events.add('setVersion');
    this.version = version;
  }
}
