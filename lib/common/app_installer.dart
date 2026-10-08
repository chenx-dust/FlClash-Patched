import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as path;

import 'app_localizations.dart';
import 'app_update.dart';
import 'exception.dart';
import 'path.dart';
import 'print.dart';
import 'request.dart';
import 'system.dart' show ProcessRunner, system;

/// Waits for the app to exit before touching its files; the pid and paths are
/// arguments, so nothing is interpolated into the script.
const _macosInstallScript = r'''
pid="$1"; dmg="$2"; app="$3"
while kill -0 "$pid" 2>/dev/null; do sleep 0.2; done
mnt="$(mktemp -d)" || exit 1
staging="$app.update"
backup="$app.previous"
rm -rf "$staging" "$backup"
if hdiutil attach -nobrowse -readonly -noautoopen -mountpoint "$mnt" "$dmg"; then
  src="$(find "$mnt" -maxdepth 1 -name '*.app' -print -quit)"
  if [ -n "$src" ] && ditto "$src" "$staging"; then
    xattr -dr com.apple.quarantine "$staging" 2>/dev/null
    if mv "$app" "$backup"; then
      mv "$staging" "$app" || mv "$backup" "$app"
    fi
  fi
  hdiutil detach "$mnt" -quiet || hdiutil detach "$mnt" -force -quiet
fi
rmdir "$mnt" 2>/dev/null
rm -rf "$staging" "$dmg"
[ -d "$app" ] && rm -rf "$backup"
open "$app"
''';

const _relaunchScript = r'''
while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
exec "$2"
''';

/// Root installs a private copy it re-hashes, as the user-writable original
/// could be swapped after the check; the old Helper rejects the new Core.
@visibleForTesting
const packageInstallScript = r'''
set -eu
src="$1"; sha256="$2"; shift 2
dir="$(mktemp -d)"
trap 'rm -rf "$dir"' EXIT
pkg="$dir/$(basename "$src")"
cp -- "$src" "$pkg"
printf '%s  %s\n' "$sha256" "$pkg" | sha256sum -c --status -
DEBIAN_FRONTEND=noninteractive "$@" "$pkg"
systemctl --no-ask-password try-restart flclash-helper.service >/dev/null 2>&1 || true
''';

/// Set by the AppImage runtime for the instance that is exiting; inherited,
/// they would point the relaunched image at the old, unmounted squashfs.
const _appImageRuntimeVariables = {'APPDIR', 'APPIMAGE', 'ARGV0', 'OWD'};

class AppInstaller {
  const AppInstaller();

  Future<File> download(
    AppUpdatePlan plan, {
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    final directory = await _downloadDirectory(plan.target);
    final file = File(
      plan.target.package == UpdatePackage.linuxAppImage
          ? path.join(directory, '.${plan.asset.name}.download')
          : path.join(directory, plan.asset.name),
    );
    await _discardStalePartialDownloads(directory, keep: '${file.path}.part');
    await request.downloadFile(
      plan.asset.url,
      file.path,
      onReceiveProgress: onReceiveProgress,
      cancelToken: cancelToken,
    );

    final actual = await sha256OfFile(file);
    if (actual != plan.asset.sha256) {
      commonPrint.log(
        'update ${plan.asset.name} sha256 $actual, expected ${plan.asset.sha256}',
        logLevel: LogLevel.error,
      );
      await file.delete();
      throw MessageException(currentAppLocalizations.updateChecksumMismatch);
    }
    return file;
  }

  Future<String> _downloadDirectory(UpdateTarget target) async {
    switch (target.package) {
      case UpdatePackage.linuxAppImage:
        final directory = path.dirname(Platform.environment['APPIMAGE']!);
        await _ensureWritable(directory);
        return directory;
      case UpdatePackage.macosDmg:
        await _ensureWritable(path.dirname(macosAppBundle));
        return (await appPath.tempDir.future).path;
      default:
        return (await appPath.tempDir.future).path;
    }
  }

  /// Partial downloads are kept for resuming, so an older release's would stay.
  Future<void> _discardStalePartialDownloads(
    String directory, {
    required String keep,
  }) async {
    try {
      await for (final entity in Directory(directory).list()) {
        final name = path.basename(entity.path);
        final isUpdatePart =
            (name.startsWith('FlClash-') || name.startsWith('.FlClash-')) &&
            name.endsWith('.part');
        if (entity is File && isUpdatePart && entity.path != keep) {
          await entity.delete();
        }
      }
    } on FileSystemException catch (error) {
      commonPrint.log(
        'stale update cleanup failed: $error',
        logLevel: LogLevel.warning,
      );
    }
  }

  Future<void> _ensureWritable(String directory) async {
    final probe = File(path.join(directory, '.flclash-update-probe-$pid'));
    try {
      await probe.writeAsString('');
      await probe.delete();
    } on FileSystemException {
      throw MessageException(currentAppLocalizations.updateNotWritable);
    }
  }

  String get macosAppBundle =>
      path.dirname(path.dirname(path.dirname(Platform.resolvedExecutable)));

  /// Inno's outer setup runs unelevated and raises UAC itself, which is what
  /// lets the `runasoriginaluser` relaunch drop back to this user. The elevated
  /// half writes the ready marker before it waits for this app to exit; a
  /// setup that exits without it was refused elevation, and the app stays up.
  Future<void> startWindowsInstaller(
    File setup, {
    Duration pollInterval = const Duration(milliseconds: 200),
  }) async {
    final ready = File('${setup.path}.ready');
    if (await ready.exists()) {
      await ready.delete();
    }
    final process = await Process.start(setup.path, [
      '/VERYSILENT',
      '/SUPPRESSMSGBOXES',
      '/NORESTART',
      '/UPDATE=1',
      '/UPDATEREADY=${ready.path}',
    ]);
    unawaited(process.stdout.drain<void>());
    unawaited(process.stderr.drain<void>());
    int? exitCode;
    unawaited(process.exitCode.then((code) => exitCode = code));
    while (!await ready.exists()) {
      if (exitCode != null) {
        commonPrint.log(
          'update installer exited with $exitCode before elevation',
          logLevel: LogLevel.warning,
        );
        throw MessageException(currentAppLocalizations.updateInstallFailed);
      }
      await Future<void>.delayed(pollInterval);
    }
  }

  Future<void> startMacosInstall(File dmg) async {
    await Process.start('/bin/sh', [
      '-c',
      _macosInstallScript,
      'flclash-update',
      '$pid',
      dmg.path,
      macosAppBundle,
    ], mode: ProcessStartMode.detached);
  }

  /// Renaming over a running AppImage is safe: the mounted image keeps the old
  /// inode alive until this process exits.
  Future<void> replaceAppImage(File downloaded) async {
    final appImage = Platform.environment['APPIMAGE']!;
    final chmod = await Process.run('chmod', ['755', downloaded.path]);
    if (chmod.exitCode != 0) {
      throw MessageException('chmod: ${chmod.stderr}');
    }
    await downloaded.rename(appImage);
  }

  Future<void> startAppImageRelaunch() {
    return _startRelaunch(
      Platform.environment['APPIMAGE']!,
      environment: Map.of(Platform.environment)
        ..removeWhere((key, _) => _appImageRuntimeVariables.contains(key)),
    );
  }

  Future<void> startRelaunch() => _startRelaunch(Platform.resolvedExecutable);

  Future<void> _startRelaunch(
    String executable, {
    Map<String, String>? environment,
  }) async {
    await Process.start(
      '/bin/sh',
      ['-c', _relaunchScript, 'flclash-relaunch', '$pid', executable],
      mode: ProcessStartMode.detached,
      environment: environment,
      includeParentEnvironment: environment == null,
    );
  }

  Future<bool> installWithPackageManager(
    AppUpdatePlan plan,
    File package, {
    ProcessRunner runProcess = Process.run,
    bool? asRoot,
  }) async {
    final command = await packageManagerInstallCommand(
      plan.target.package,
      runProcess: runProcess,
    );
    if (command == null) {
      return false;
    }
    final script = [
      '/bin/sh',
      '-c',
      packageInstallScript,
      'flclash-update',
      package.path,
      plan.asset.sha256,
      ...command,
    ];
    final ProcessResult result;
    try {
      result = (asRoot ?? system.isRunningAsRoot)
          ? await runProcess(script.first, script.sublist(1))
          : await runProcess('pkexec', script);
    } on ProcessException catch (error) {
      commonPrint.log(
        'package update unavailable: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
      return false;
    }
    if (result.exitCode != 0) {
      commonPrint.log(
        'package update exited with ${result.exitCode}: '
        '${result.stderr.toString().trim()}',
        logLevel: LogLevel.warning,
      );
      return false;
    }
    await package.delete();
    return true;
  }

  Future<ApkInstallStatus> installApk(File apk) async {
    return await app?.installApk(apk.path) ?? ApkInstallStatus.failed;
  }
}

/// Front ends that resolve dependencies come before dpkg and rpm.
Future<List<String>?> packageManagerInstallCommand(
  UpdatePackage package, {
  ProcessRunner runProcess = Process.run,
}) async {
  final candidates = switch (package) {
    UpdatePackage.linuxDeb => [
      ['apt-get', 'install', '-y'],
      ['dpkg', '-i'],
    ],
    UpdatePackage.linuxRpm => [
      ['dnf', 'install', '-y'],
      ['zypper', '--non-interactive', 'install', '--allow-unsigned-rpm'],
      ['rpm', '-U'],
    ],
    UpdatePackage.linuxPacman => [
      ['pacman', '-U', '--noconfirm'],
    ],
    _ => const <List<String>>[],
  };
  for (final [tool, ...arguments] in candidates) {
    try {
      final result = await runProcess('/bin/sh', [
        '-c',
        'command -v "\$1"',
        'sh',
        tool,
      ]);
      final resolved = result.stdout.toString().trim();
      if (result.exitCode == 0 && resolved.startsWith('/')) {
        return [resolved, ...arguments];
      }
    } on ProcessException {
      continue;
    }
  }
  return null;
}

const appInstaller = AppInstaller();
