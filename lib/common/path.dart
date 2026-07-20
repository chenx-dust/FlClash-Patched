import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_foundation/path_provider_foundation.dart';

const _unixSocketPathMaxBytes = 100;
const _unixFallbackRuntimeRoot = '/tmp';

String _secureRandomToken(int byteLength) {
  final random = Random.secure();
  final bytes = List.generate(byteLength, (_) => random.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}

String _trimUnixTrailingSeparators(String path) {
  var normalized = path;
  while (normalized.length > 1 && normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

String _joinUnixPath(String root, String name) {
  final normalizedRoot = _trimUnixTrailingSeparators(root);
  return normalizedRoot == '/' ? '/$name' : '$normalizedRoot/$name';
}

bool _isUsableUnixRuntimeRoot(String? path) {
  if (path == null || !path.startsWith('/')) {
    return false;
  }
  final normalizedPath = _trimUnixTrailingSeparators(path);
  return normalizedPath != '/' && normalizedPath != _unixFallbackRuntimeRoot;
}

@visibleForTesting
({String runtimeDirectory, String socketPath}) resolveUnixSocketPaths({
  required bool isLinux,
  required bool isMacOS,
  required Map<String, String> environment,
  required String systemTemp,
  required String runtimeToken,
  required String socketToken,
  int maxSocketPathBytes = _unixSocketPathMaxBytes,
}) {
  String? preferredRuntimeDirectory;
  if (isLinux) {
    final xdgRuntimeDirectory = environment['XDG_RUNTIME_DIR'];
    if (_isUsableUnixRuntimeRoot(xdgRuntimeDirectory)) {
      preferredRuntimeDirectory = _joinUnixPath(
        xdgRuntimeDirectory!,
        'flclash',
      );
    }
  } else if (isMacOS && _isUsableUnixRuntimeRoot(systemTemp)) {
    preferredRuntimeDirectory = _joinUnixPath(systemTemp, 'flclash');
  }

  if (preferredRuntimeDirectory != null) {
    final preferredSocketPath = _joinUnixPath(
      preferredRuntimeDirectory,
      'ipc-$socketToken.sock',
    );
    if (utf8.encode(preferredSocketPath).length <= maxSocketPathBytes) {
      return (
        runtimeDirectory: preferredRuntimeDirectory,
        socketPath: preferredSocketPath,
      );
    }
  }

  final fallbackRuntimeDirectory =
      '$_unixFallbackRuntimeRoot/flclash-$runtimeToken';
  return (
    runtimeDirectory: fallbackRuntimeDirectory,
    socketPath: '$fallbackRuntimeDirectory/ipc-$socketToken.sock',
  );
}

final _unixSocketPaths = resolveUnixSocketPaths(
  isLinux: Platform.isLinux,
  isMacOS: Platform.isMacOS,
  environment: Platform.environment,
  systemTemp: Directory.systemTemp.path,
  runtimeToken: _secureRandomToken(16),
  socketToken: _secureRandomToken(16),
);
final unixSocketRuntimeDirectory = _unixSocketPaths.runtimeDirectory;
final unixSocketPath = _unixSocketPaths.socketPath;
final windowsPipeName = '\\\\.\\pipe\\FlClashCore_${_secureRandomToken(16)}';

class AppPath {
  static AppPath? _instance;
  Completer<Directory> dataDir = Completer();
  Completer<Directory> downloadDir = Completer();
  Completer<Directory> tempDir = Completer();
  Completer<Directory> cacheDir = Completer();
  late String appDirPath;

  AppPath._internal() {
    appDirPath = join(dirname(Platform.resolvedExecutable));
    _initDataDir();
    getTemporaryDirectory().then((value) {
      tempDir.complete(value);
    });
    getDownloadsDirectory().then((value) {
      downloadDir.complete(value);
    });
    getApplicationCacheDirectory().then((value) {
      cacheDir.complete(value);
    });
  }

  factory AppPath() {
    _instance ??= AppPath._internal();
    return _instance!;
  }

  Future<void> _initDataDir() async {
    final supportDir = await getApplicationSupportDirectory();
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

  Future<String> _getIOSAppGroupPath() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
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
    if (!await source.exists()) {
      return;
    }
    if (equals(source.path, target.path)) {
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
    final directory = await downloadDir.future;
    return directory.path;
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
    return join(mTempDir.path, 'temp${utils.id}');
  }

  Future<String> get lockFilePath async {
    final homeDirPath = await appPath.homeDirPath;
    return join(homeDirPath, 'FlClash.lock');
  }

  Future<String> get configFilePath async {
    final mHomeDirPath = await homeDirPath;
    return join(mHomeDirPath, 'config.yaml');
  }

  Future<String> get sharedFilePath async {
    final mHomeDirPath = await homeDirPath;
    return join(mHomeDirPath, 'shared.json');
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

  Future<String> getIconsCacheDir() async {
    final directory = await cacheDir.future;
    return join(directory.path, 'icons');
  }

  Future<String> getProvidersRootPath() async {
    final directory = await profilesPath;
    return join(directory, 'providers');
  }

  Future<String> getProvidersDirPath(String id) async {
    final directory = await profilesPath;
    return join(directory, 'providers', id);
  }

  Future<String> getProvidersFilePath(
    String id,
    String type,
    String url,
  ) async {
    final directory = await profilesPath;
    return join(directory, 'providers', id, type, url.toMd5());
  }

  Future<String> get tempPath async {
    final directory = await tempDir.future;
    return directory.path;
  }
}

final appPath = AppPath();
