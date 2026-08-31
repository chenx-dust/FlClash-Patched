import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

import 'path.dart' show appPath;

const _defaultPrefix = 'flutter.';

void configurePortablePreferences() {
  if (!appPath.isPortable) {
    return;
  }
  SharedPreferencesStorePlatform.instance = PortableSharedPreferencesStore(
    File(join(appPath.appDirPath, 'config', 'shared_preferences.json')),
  );
}

class PortableSharedPreferencesStore extends SharedPreferencesStorePlatform {
  final File file;
  Map<String, Object>? _cachedPreferences;
  Future<void> _pendingOperation = Future<void>.value();

  PortableSharedPreferencesStore(this.file);

  @override
  Future<bool> clear() {
    return clearWithParameters(
      ClearParameters(filter: PreferencesFilter(prefix: _defaultPrefix)),
    );
  }

  @override
  Future<bool> clearWithPrefix(String prefix) {
    return clearWithParameters(
      ClearParameters(filter: PreferencesFilter(prefix: prefix)),
    );
  }

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) {
    return _synchronized(() async {
      final preferences = await _readPreferences();
      final filter = parameters.filter;
      preferences.removeWhere(
        (key, _) =>
            key.startsWith(filter.prefix) &&
            (filter.allowList == null || filter.allowList!.contains(key)),
      );
      return _writePreferences(preferences);
    });
  }

  @override
  Future<Map<String, Object>> getAll() {
    return getAllWithParameters(
      GetAllParameters(filter: PreferencesFilter(prefix: _defaultPrefix)),
    );
  }

  @override
  Future<Map<String, Object>> getAllWithPrefix(String prefix) {
    return getAllWithParameters(
      GetAllParameters(filter: PreferencesFilter(prefix: prefix)),
    );
  }

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) {
    return _synchronized(() async {
      final filter = parameters.filter;
      final preferences = Map<String, Object>.from(await _readPreferences());
      preferences.removeWhere(
        (key, _) =>
            !key.startsWith(filter.prefix) ||
            (filter.allowList != null && !filter.allowList!.contains(key)),
      );
      return preferences;
    });
  }

  @override
  Future<bool> remove(String key) {
    return _synchronized(() async {
      final preferences = await _readPreferences();
      preferences.remove(key);
      return _writePreferences(preferences);
    });
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    return _synchronized(() async {
      final preferences = await _readPreferences();
      preferences[key] = value;
      return _writePreferences(preferences);
    });
  }

  Future<Map<String, Object>> _readPreferences() async {
    final cachedPreferences = _cachedPreferences;
    if (cachedPreferences != null) {
      return cachedPreferences;
    }
    if (!await file.exists()) {
      return _cachedPreferences = <String, Object>{};
    }
    final contents = await file.readAsString();
    if (contents.isEmpty) {
      return _cachedPreferences = <String, Object>{};
    }
    final decoded = json.decode(contents);
    if (decoded is! Map) {
      throw const FormatException('Preferences root must be a JSON object.');
    }
    return _cachedPreferences = decoded.cast<String, Object>();
  }

  Future<bool> _writePreferences(Map<String, Object> preferences) async {
    final temporaryFile = File('${file.path}.tmp');
    try {
      await file.parent.create(recursive: true);
      await temporaryFile.writeAsString(json.encode(preferences), flush: true);
      await temporaryFile.rename(file.path);
      return true;
    } catch (error) {
      debugPrint('Error saving portable preferences: $error');
      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
      return false;
    }
  }

  Future<T> _synchronized<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _pendingOperation = _pendingOperation.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
