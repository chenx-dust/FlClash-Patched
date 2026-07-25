import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/models/models.dart';

import 'dav_secret_storage.dart';
import 'preferences.dart';
import 'task.dart';

typedef MigrationTransform =
    Future<MigrationData> Function(Map<String, Object?> configMap);

abstract interface class MigrationStore {
  Future<Map<String, Object?>?> getConfigMap();

  Future<int> getVersion();

  Future<Map<String, Object?>?> getClashConfigMap();

  Future<void> saveDavPassword(String password);

  Future<void> restore(MigrationData data);

  Future<bool> saveConfig(Config config);

  Future<void> clearClashConfig();

  Future<void> setVersion(int version);
}

class _AppMigrationStore implements MigrationStore {
  const _AppMigrationStore();

  @override
  Future<Map<String, Object?>?> getConfigMap() => preferences.getConfigMap();

  @override
  Future<int> getVersion() => preferences.getVersion();

  @override
  Future<Map<String, Object?>?> getClashConfigMap() =>
      preferences.getClashConfigMap();

  @override
  Future<void> saveDavPassword(String password) =>
      davSecretStorage.save(password);

  @override
  Future<void> restore(MigrationData data) {
    return database.restore(
      data.profiles,
      data.scripts,
      data.rules,
      data.links,
      data.proxyGroups,
    );
  }

  @override
  Future<bool> saveConfig(Config config) => preferences.saveConfig(config);

  @override
  Future<void> clearClashConfig() => preferences.clearClashConfig();

  @override
  Future<void> setVersion(int version) => preferences.setVersion(version);
}

class Migration {
  final MigrationStore _store;
  final MigrationTransform _migrateV0;

  Migration({required MigrationStore store, MigrationTransform? migrateV0})
    : _store = store,
      _migrateV0 = migrateV0 ?? oldToNowTask;

  static const currentVersion = 1;

  Future<Config> run() async {
    final configMap = await _store.getConfigMap();
    var oldVersion = await _store.getVersion();
    Config? config;
    if (oldVersion > currentVersion) {
      throw StateError(
        'Local data version $oldVersion is newer than $currentVersion.',
      );
    }
    if (oldVersion == currentVersion) {
      try {
        config = Config.realFromJson(configMap);
      } catch (_) {
        if (!_isV0(configMap)) {
          throw StateError(
            'Local data is damaged. A reset is required to fix this issue.',
          );
        }
        oldVersion = 0;
      }
      if (config != null) {
        final hasLegacyDavPassword = await _saveLegacyDavPassword(configMap);
        if (hasLegacyDavPassword && !await _store.saveConfig(config)) {
          throw StateError('Failed to remove the legacy WebDAV password');
        }
        return config;
      }
    }

    await _saveLegacyDavPassword(configMap);
    MigrationData data = MigrationData(configMap: configMap);
    var shouldClearClashConfig = false;
    if (oldVersion == 0) {
      final clashConfigMap = await _store.getClashConfigMap();
      shouldClearClashConfig = clashConfigMap != null;
      if (_isV0(configMap) && configMap != null) {
        if (clashConfigMap != null) {
          configMap['patchClashConfig'] = clashConfigMap;
        }
        data = await _migrateV0(configMap);
      }
    }

    config = Config.realFromJson(data.configMap);
    await _store.restore(data);
    if (!await _store.saveConfig(config)) {
      throw StateError('Failed to save migrated preferences');
    }
    if (shouldClearClashConfig) {
      await _store.clearClashConfig();
    }
    await _store.setVersion(currentVersion);
    return config;
  }

  Future<bool> _saveLegacyDavPassword(Map<String, Object?>? configMap) async {
    final password = _getLegacyDavPassword(configMap);
    if (password == null) {
      return false;
    }
    await _store.saveDavPassword(password);
    return true;
  }
}

bool _isV0(Map<String, Object?>? configMap) =>
    configMap?['proxiesStyle'] != null;

String? _getLegacyDavPassword(Map<String, Object?>? configMap) {
  final dav = configMap?['davProps'] ?? configMap?['dav'];
  if (dav is! Map) {
    return null;
  }
  final password = dav['password'];
  return password is String && password.isNotEmpty ? password : null;
}

final migration = Migration(store: const _AppMigrationStore());
