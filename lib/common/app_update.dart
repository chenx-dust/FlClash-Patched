import 'dart:ffi';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import 'constant.dart' show repository;
import 'system.dart' show ProcessRunner;

const _buildArch = String.fromEnvironment('APP_ARCH');

enum UpdatePackage {
  windowsInstaller,
  windowsPortable,
  androidApk,
  macosDmg,
  linuxAppImage,
  linuxDeb,
  linuxRpm,
  linuxPacman,
  linuxPortable,
  unsupported;

  bool get installsInPlace => switch (this) {
    windowsInstaller || androidApk || macosDmg || linuxAppImage => true,
    _ => false,
  };

  bool get isPackageManaged => switch (this) {
    linuxDeb || linuxRpm || linuxPacman => true,
    _ => false,
  };

  bool get updatesInApp => installsInPlace || isPackageManaged;
}

class UpdateTarget {
  final UpdatePackage package;
  final String arch;

  const UpdateTarget(this.package, this.arch);

  static const unsupported = UpdateTarget(UpdatePackage.unsupported, '');

  /// Mirrors the file names `setup.dart` and flutter_distributor publish,
  /// `FlClash-<version>-<suffix>`.
  String? get assetSuffix => switch (package) {
    UpdatePackage.windowsInstaller => '-windows-$arch-setup.exe',
    UpdatePackage.windowsPortable => '-windows-$arch.zip',
    UpdatePackage.androidApk => '-android-$arch.apk',
    UpdatePackage.macosDmg => '-macos-$arch.dmg',
    UpdatePackage.linuxAppImage => '-linux-$arch.AppImage',
    UpdatePackage.linuxDeb => '-linux-$arch.deb',
    UpdatePackage.linuxRpm => '-linux-$arch.rpm',
    UpdatePackage.linuxPacman => '-linux-$arch.tar.zst',
    UpdatePackage.linuxPortable => '-linux-$arch.zip',
    UpdatePackage.unsupported => null,
  };

  @override
  bool operator ==(Object other) =>
      other is UpdateTarget && other.package == package && other.arch == arch;

  @override
  int get hashCode => Object.hash(package, arch);

  @override
  String toString() => 'UpdateTarget(${package.name}, $arch)';
}

String? _androidAbiName(Abi abi) => switch (abi) {
  Abi.androidArm64 => 'arm64-v8a',
  Abi.androidArm => 'armeabi-v7a',
  Abi.androidX64 => 'x86_64',
  _ => null,
};

String? _desktopArch(Abi abi, String buildArch) {
  if (buildArch.isNotEmpty) {
    return buildArch;
  }
  return switch (abi) {
    Abi.windowsX64 || Abi.linuxX64 || Abi.macosX64 => 'x64',
    Abi.windowsArm64 || Abi.linuxArm64 || Abi.macosArm64 => 'arm64',
    _ => null,
  };
}

/// The Flutter binary is identical across a platform's package formats, so
/// the format is read from how this copy sits on disk; only the architecture
/// is baked in at build time, because x64 and x64-v3 differ in the Core alone.
Future<UpdateTarget> detectUpdateTarget({
  String? operatingSystem,
  Abi? abi,
  String buildArch = _buildArch,
  String? executable,
  Map<String, String>? environment,
  bool Function(String path)? exists,
  ProcessRunner runProcess = Process.run,
}) async {
  final os = operatingSystem ?? Platform.operatingSystem;
  final currentAbi = abi ?? Abi.current();
  final exe = executable ?? Platform.resolvedExecutable;
  final env = environment ?? Platform.environment;
  final pathExists =
      exists ??
      (String p) =>
          FileSystemEntity.typeSync(p) != FileSystemEntityType.notFound;
  final paths = path.Context(
    style: os == 'windows' ? path.Style.windows : path.Style.posix,
  );
  final exeDir = paths.dirname(exe);

  if (os == 'android') {
    final abiName = _androidAbiName(currentAbi);
    return abiName == null
        ? UpdateTarget.unsupported
        : UpdateTarget(UpdatePackage.androidApk, abiName);
  }
  final arch = _desktopArch(currentAbi, buildArch);
  if (arch == null) {
    return UpdateTarget.unsupported;
  }
  switch (os) {
    case 'windows':
      if (pathExists(paths.join(exeDir, 'config'))) {
        return UpdateTarget(UpdatePackage.windowsPortable, arch);
      }
      if (pathExists(paths.join(exeDir, 'unins000.exe'))) {
        return UpdateTarget(UpdatePackage.windowsInstaller, arch);
      }
    case 'macos':
      if (exe.contains('.app/Contents/MacOS/')) {
        return UpdateTarget(UpdatePackage.macosDmg, arch);
      }
    case 'linux':
      if (env['APPIMAGE']?.isNotEmpty == true) {
        return UpdateTarget(UpdatePackage.linuxAppImage, arch);
      }
      if (pathExists(paths.join(exeDir, 'config'))) {
        return UpdateTarget(UpdatePackage.linuxPortable, arch);
      }
      final owner = await findLinuxPackageOwner(exe, runProcess);
      if (owner != null) {
        return UpdateTarget(owner, arch);
      }
  }
  return UpdateTarget.unsupported;
}

Future<UpdatePackage?> findLinuxPackageOwner(
  String executable,
  ProcessRunner runProcess,
) async {
  const queries = [
    (UpdatePackage.linuxDeb, 'dpkg', '-S'),
    (UpdatePackage.linuxRpm, 'rpm', '-qf'),
    (UpdatePackage.linuxPacman, 'pacman', '-Qo'),
  ];
  for (final (package, command, flag) in queries) {
    try {
      final result = await runProcess(command, [flag, executable]);
      if (result.exitCode == 0) {
        return package;
      }
    } on ProcessException {
      continue;
    }
  }
  return null;
}

final _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');

ReleaseAsset? _verifiedAsset(Object? asset) => switch (asset) {
  {
    'name': final String name,
    'url': final String url,
    'size': final int size,
    'sha256': final String sha256,
  }
      when _sha256Pattern.hasMatch(sha256) =>
    ReleaseAsset(name: name, url: url, size: size, sha256: sha256),
  _ => null,
};

/// `version.json`, written by `tool/release_manifest.sh` into every release.
class ReleaseManifest {
  final String tag;

  /// The release body, which carries the changelog `parseReleaseChangelog`
  /// reads.
  final String notes;
  final List<ReleaseAsset> assets;

  const ReleaseManifest({
    required this.tag,
    required this.notes,
    this.assets = const [],
  });

  /// An asset without a well-formed hash is dropped rather than rejected, so
  /// the release still announces itself and that package falls back to the
  /// release page.
  factory ReleaseManifest.fromJson(Object? json) {
    if (json case {'tag': final String tag}) {
      final assets = json['assets'];
      return ReleaseManifest(
        tag: tag,
        notes: json['notes'] as String? ?? '',
        assets: [
          if (assets is List)
            for (final asset in assets) ?_verifiedAsset(asset),
        ],
      );
    }
    throw const FormatException('Unsupported release manifest');
  }

  /// The REST API's `releases/latest`, for releases published before
  /// `version.json`; GitHub reports an asset's hash as a `sha256:` digest.
  factory ReleaseManifest.fromGitHubRelease(Object? json) {
    if (json case {'tag_name': final String tag}) {
      final assets = json['assets'];
      return ReleaseManifest(
        tag: tag,
        notes: json['body'] as String? ?? '',
        assets: [
          if (assets is List)
            for (final asset in assets)
              if (asset case {
                'name': final String name,
                'browser_download_url': final String url,
                'size': final int size,
                'digest': final String digest,
              } when digest.startsWith('sha256:'))
                ?_verifiedAsset({
                  'name': name,
                  'url': url,
                  'size': size,
                  'sha256': digest.substring('sha256:'.length),
                }),
        ],
      );
    }
    throw const FormatException('Unsupported GitHub release');
  }
}

class ReleaseAsset {
  final String name;
  final String url;
  final int size;
  final String sha256;

  const ReleaseAsset({
    required this.name,
    required this.url,
    required this.size,
    required this.sha256,
  });
}

class AppUpdatePlan {
  final UpdateTarget target;
  final ReleaseAsset asset;

  const AppUpdatePlan({required this.target, required this.asset});
}

AppUpdatePlan? planAppUpdate(ReleaseManifest release, UpdateTarget target) {
  final suffix = target.assetSuffix;
  if (suffix == null) {
    return null;
  }
  final asset = release.assets
      .where(
        (asset) =>
            asset.name.startsWith('FlClash-') && asset.name.endsWith(suffix),
      )
      .firstOrNull;
  return asset == null ? null : AppUpdatePlan(target: target, asset: asset);
}

/// What a copy that cannot update itself opens in the browser: its own asset
/// when the release has one, else the release page.
Uri browserDownloadUri(AppUpdatePlan? plan) => Uri.parse(
  plan?.asset.url ?? 'https://github.com/$repository/releases/latest',
);

Future<String> sha256OfFile(File file) async {
  final digest = await sha256.bind(file.openRead()).first;
  return digest.toString();
}
