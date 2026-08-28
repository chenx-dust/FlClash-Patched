import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_foundation/path_provider_foundation.dart';

import 'portable_pref.dart';

class AppPath {
  static AppPath? _instance;
  Completer<Directory> dataDir = Completer();
  late final Future<Directory?> _downloadDir = downloadDirectory();
  Completer<Directory> tempDir = Completer();
  Completer<Directory> cacheDir = Completer();
  late String appDirPath;
  late final bool isPortable = isPortableDirectory(appDirPath);

  @visibleForTesting
  static Future<Directory> Function() supportDirectory =
      getApplicationSupportDirectory;

  @visibleForTesting
  static Future<Directory> Function() temporaryDirectory =
      getTemporaryDirectory;

  @visibleForTesting
  static Future<Directory> Function() cacheDirectory =
      getApplicationCacheDirectory;

  @visibleForTesting
  static Future<Directory?> Function() downloadDirectory =
      getDownloadsDirectory;

  AppPath._internal() {
    appDirPath = join(dirname(Platform.resolvedExecutable));
    _initDataDir();
    _initTempDir();
    _initCacheDir();
  }

  factory AppPath() {
    _instance ??= AppPath._internal();
    return _instance!;
  }

  Future<void> _initDataDir() async {
    if (isPortable) {
      dataDir.complete(Directory(join(appDirPath, 'config')));
      return;
    }
    final supportDir = await supportDirectory();
    try {
      if (!system.isIOS) {
        dataDir.complete(supportDir);
        return;
      }
      final appGroupPath = await _getIOSAppGroupPath();
      if (appGroupPath.isEmpty) {
        dataDir.complete(supportDir);
        return;
      }
      final appGroupDir = Directory(appGroupPath);
      await appGroupDir.create(recursive: true);
      await _copyDirectoryContentsIfMissing(supportDir, appGroupDir);
      dataDir.complete(appGroupDir);
    } catch (_) {
      dataDir.complete(supportDir);
    }
  }

  Future<void> _initCacheDir() async {
    await dataDir.future;
    if (isPortable) {
      cacheDir.complete(Directory(join(await homeDirPath, '.cache')));
      return;
    }
    final dir = await cacheDirectory();
    cacheDir.complete(dir);
  }

  Future<void> _initTempDir() async {
    await dataDir.future;
    if (isPortable) {
      final portableTmpDir = Directory(join(await homeDirPath, 'tmp'));
      if (await portableTmpDir.exists()) {
        tempDir.complete(portableTmpDir);
        return;
      }
    }
    final dir = await temporaryDirectory();
    tempDir.complete(dir);
  }

  Future<String> _getIOSAppGroupPath() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return await PathProviderFoundation().getContainerPath(
            appGroupIdentifier: 'group.${packageInfo.packageName}',
          ) ??
          '';
    } catch (_) {
      return '';
    }
  }

  Future<void> _copyDirectoryContentsIfMissing(
    Directory source,
    Directory target,
  ) async {
    if (!await source.exists() || equals(source.path, target.path)) {
      return;
    }
    await for (final entity in source.list(recursive: true)) {
      final relativePath = relative(entity.path, from: source.path);
      final targetPath = join(target.path, relativePath);
      if (entity is Directory) {
        await Directory(targetPath).create(recursive: true);
        continue;
      }
      if (entity is! File || await File(targetPath).exists()) {
        continue;
      }
      await File(targetPath).parent.create(recursive: true);
      await entity.copy(targetPath);
    }
  }

  String get executableExtension {
    return system.isWindows ? '.exe' : '';
  }

  String get executableDirPath {
    final currentExecutablePath = Platform.resolvedExecutable;
    return dirname(currentExecutablePath);
  }

  String get corePath {
    return join(executableDirPath, 'FlClashCore$executableExtension');
  }

  String get helperPath {
    return join(executableDirPath, '$appHelperService$executableExtension');
  }

  Future<String> get downloadDirPath async {
    final directory = await _downloadDir;
    return directory?.path ?? await homeDirPath;
  }

  Future<String> get homeDirPath async {
    final directory = await dataDir.future;
    return directory.path;
  }

  Future<String> get databasePath async {
    final mHomeDirPath = await homeDirPath;
    return join(mHomeDirPath, 'database.sqlite');
  }

  Future<String> get backupFilePath async {
    final mHomeDirPath = await homeDirPath;
    return join(mHomeDirPath, 'backup.zip');
  }

  Future<String> get restoreDirPath async {
    final mHomeDirPath = await homeDirPath;
    return join(mHomeDirPath, 'restore');
  }

  Future<String> get tempFilePath async {
    final mTempDir = await tempDir.future;
    return join(mTempDir.path, 'temp$uniqueId');
  }

  Future<String> get configFilePath async {
    final mHomeDirPath = await homeDirPath;
    return join(mHomeDirPath, 'config.yaml');
  }

  Future<String> get sharedPreferencesPath async {
    final directory = await dataDir.future;
    return join(directory.path, 'shared_preferences.json');
  }

  Future<String> get profilesPath async {
    final directory = await dataDir.future;
    return join(directory.path, profilesDirectoryName);
  }

  Future<String> getProfilePath(String fileName) async {
    return join(await profilesPath, '$fileName.yaml');
  }

  Future<String> get scriptsDirPath async {
    final path = await homeDirPath;
    return join(path, 'scripts');
  }

  Future<String> getScriptPath(String fileName) async {
    final path = await scriptsDirPath;
    return join(path, '$fileName.js');
  }

  Future<String> getProvidersRootPath() async {
    final directory = await profilesPath;
    return join(directory, providersDirectoryName);
  }

  Future<String> getProviderDirPath(int profileId, String type) async {
    final directory = await getProvidersRootPath();
    return join(directory, profileId.toString(), type);
  }

  Future<void> ensureProviderDirs(int profileId) async {
    for (final type in const [
      proxiesProviderDirectoryName,
      rulesProviderDirectoryName,
    ]) {
      final directory = Directory(await getProviderDirPath(profileId, type));
      if (await directory.exists()) {
        continue;
      }
      await directory.create(recursive: true);
    }
  }

  Future<String> get tempPath async {
    final directory = await tempDir.future;
    return directory.path;
  }
}

final appPath = AppPath();

String getBackupFileName() {
  return '${appName}_backup_${DateTime.now().show}.zip';
}

String get logFileName {
  return '${appName}_${DateTime.now().show}.log';
}
