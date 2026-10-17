import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

const _allTargets = <String, String>{
  'android': 'apk',
  'ios': 'ipa',
  'linux': 'deb,appimage,rpm',
  'macos': 'dmg',
  'windows': 'exe,zip',
};

const _androidFlutterTarget = {
  'arm': 'android-arm',
  'arm64': 'android-arm64',
  'amd64': 'android-x64',
};

const _hostPlatform = {
  'linux': 'linux',
  'macos': 'macos',
  'windows': 'windows',
};

Future<void> main(List<String> args) async {
  final parser = createSetupArgParser();

  if (args.contains('--help') || args.contains('-h')) {
    _showHelp(parser);
    exit(0);
  }

  final results = parser.parse(args);
  final rest = results.rest;

  final hostOs = Platform.operatingSystem;
  final host = _hostPlatform[hostOs];
  if (host == null) {
    stderr.writeln('Unsupported host platform: $hostOs');
    exit(1);
  }

  final platform = rest.isNotEmpty ? rest.first : host;
  final allowed = [host, 'android', if (host == 'macos') 'ios'];

  if (!allowed.contains(platform)) {
    stderr.writeln(
      'Cannot build "$platform" on $hostOs. Allowed: ${allowed.join(', ')}',
    );
    _showHelp(parser);
    exit(1);
  }

  final env = results['env'] as String;
  final rootDir = Directory.current.path;
  final skipped = packagesNotBuildingAssets(
    File(p.join(rootDir, 'pubspec.yaml')).readAsStringSync(),
  );
  if (skipped.isNotEmpty) {
    stderr.writeln(
      'pubspec.yaml sets hooks.user_defines.<package>.build_assets: false '
      'for ${skipped.join(', ')}; a package built this way would ship '
      'whatever is left in libclash/ and no Rust library. '
      'Restore "build_assets: true".',
    );
    exit(1);
  }
  final arch = _detectArch();
  final targets = createPackageTargets(platform, results['targets']);
  final androidArch = results['arch'] as String?;
  final verbose = results['verbose'] as bool;

  final exitCode = await _package(
    platform,
    env,
    targets,
    rootDir,
    arch,
    androidArch: androidArch,
    verbose: verbose,
  );
  exit(exitCode);
}

ArgParser createSetupArgParser() {
  return ArgParser()
    ..addOption(
      'env',
      defaultsTo: 'pre',
      allowed: ['dev', 'pre', 'stable'],
      help: 'Application environment',
    )
    ..addOption(
      'targets',
      valueHelp: 'exe,zip,dmg,apk,...',
      help: 'Package targets (default: all for platform)',
    )
    ..addOption(
      'arch',
      valueHelp: 'arm,arm64,amd64',
      allowed: ['arm', 'arm64', 'amd64'],
      help: 'Target architecture (Android only)',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Enable verbose Flutter build output',
    );
}

List<String> createFlutterBuildArgs({
  required String platform,
  required bool verbose,
}) {
  final flutterBuildArgs = <String>[
    if (verbose) 'verbose',
    'dart-define-from-file=env.json',
  ];
  if (platform == 'android') {
    flutterBuildArgs.add('split-per-abi');
  }
  return flutterBuildArgs;
}

Map<String, String> createBuildEnvironment(String env) {
  return {'APP_ENV': env};
}

/// Packages whose build hook `pubspec.yaml` turns into a no-op.
List<String> packagesNotBuildingAssets(String pubspec) {
  final document = loadYaml(pubspec);
  if (document is! Map) return const [];
  final defines = (document['hooks'] as Map?)?['user_defines'];
  if (defines is! Map) return const [];
  return [
    for (final MapEntry(:key, :value) in defines.entries)
      if (value is Map && value['build_assets'] == false) key.toString(),
  ]..sort();
}

String createPackageTargets(String platform, String? customTargets) {
  return customTargets ?? _allTargets[platform]!;
}

void _showHelp(ArgParser parser) {
  stderr.writeln('Usage: dart setup.dart [platform] [options]');
  stderr.writeln(
    'Platform: current host platform (default), android, or ios (on macOS)',
  );
  stderr.writeln();
  stderr.writeln('Default package targets:');
  _allTargets.forEach((p, t) => stderr.writeln('  $p: $t'));
  stderr.writeln();
  stderr.writeln(parser.usage);
}

Future<int> _package(
  String platform,
  String env,
  String targets,
  String rootDir,
  String arch, {
  String? androidArch,
  required bool verbose,
}) async {
  final file = File(p.join(rootDir, 'env.json'));
  await file.writeAsString(jsonEncode(createBuildEnvironment(env)));

  if (platform == 'ios') {
    return _packageIOS(rootDir, verbose: verbose);
  }

  final flutterBuildArgs = createFlutterBuildArgs(
    platform: platform,
    verbose: verbose,
  );
  final descriptionArgs = <String>[];
  if (platform != 'android') {
    descriptionArgs.addAll(['--description', arch]);
  }

  final depExit = await _ensureDependencies(platform);
  if (depExit != 0) return depExit;

  final activateResult = await Process.run('dart', [
    'pub',
    'global',
    'activate',
    '-s',
    'git',
    'https://github.com/chen08209/flutter_distributor.git',
    '--git-ref',
    'v0.6.11-flclash.4',
    '--git-path',
    'packages/flutter_distributor',
  ]);
  if (activateResult.exitCode != 0) {
    stderr.write(activateResult.stderr);
    return activateResult.exitCode;
  }

  final process = await Process.start(
    'flutter_distributor',
    [
      'package',
      '--skip-clean',
      '--platform',
      platform,
      '--targets',
      targets,
      if (androidArch != null)
        '--build-target-platform=${_androidFlutterTarget[androidArch]!}',
      if (flutterBuildArgs.isNotEmpty)
        '--flutter-build-args=${flutterBuildArgs.join(',')}',
      ...descriptionArgs,
    ],
    includeParentEnvironment: true,
    runInShell: Platform.isWindows,
  );

  process.stdout.listen((data) {
    stdout.write(utf8.decode(data));
  });
  process.stderr.listen((data) {
    stderr.write(utf8.decode(data));
  });
  final exitCode = await process.exitCode;
  return exitCode;
}

const _iosAppBundleId = 'com.follow.clash';

/// The IPA ships unsigned for whoever installs it to sign; each bundle still
/// carries its own entitlements, since a re-signer copies them from the bundle.
Future<int> _packageIOS(String rootDir, {required bool verbose}) async {
  final build = await Process.start('flutter', [
    if (verbose) '--verbose',
    'build',
    'ios',
    '--release',
    '--no-codesign',
    '--dart-define-from-file=env.json',
  ], workingDirectory: rootDir);
  build.stdout.listen(stdout.add);
  build.stderr.listen(stderr.add);
  final buildExit = await build.exitCode;
  if (buildExit != 0) return buildExit;

  final appPath = p.join(rootDir, 'build', 'ios', 'iphoneos', 'Runner.app');
  if (!Directory(appPath).existsSync()) {
    stderr.writeln('iOS app bundle not found: $appPath');
    return 1;
  }
  final frameworks = Directory(p.join(appPath, 'Frameworks'));
  for (final framework in frameworks.listSync()) {
    final exitCode = await _adHocSign(framework.path);
    if (exitCode != 0) return exitCode;
  }
  final tempDir = await Directory.systemTemp.createTemp('flclash_ipa_');
  try {
    // Inner bundles first: signing the app seals the extensions it embeds.
    for (final target in createIOSSigningTargets(
      rootDir: rootDir,
      appPath: appPath,
      appBundleId: _iosAppBundleId,
    )) {
      final entitlements = File(
        p.join(tempDir.path, '${p.basename(target.bundle)}.entitlements'),
      );
      await entitlements.writeAsString(
        createIOSEntitlements(
          source: File(target.entitlements).readAsStringSync(),
          appBundleId: _iosAppBundleId,
          bundleIdentifier: target.bundleIdentifier,
        ),
      );
      final exitCode = await _adHocSign(
        target.bundle,
        entitlements: entitlements.path,
      );
      if (exitCode != 0) return exitCode;
    }

    final payload = p.join(tempDir.path, 'Payload');
    final copy = await Process.run('ditto', [
      appPath,
      p.join(payload, 'Runner.app'),
    ]);
    if (copy.exitCode != 0) {
      stderr.write(copy.stderr);
      return copy.exitCode;
    }
    final pubspec =
        loadYaml(File(p.join(rootDir, 'pubspec.yaml')).readAsStringSync())
            as Map;
    final version = (pubspec['version'] as String).split('+').first;
    final distDir = Directory(p.join(rootDir, 'dist'))
      ..createSync(recursive: true);
    final ipa = p.join(distDir.path, 'FlClash-$version-ios-arm64-unsigned.ipa');
    final archive = await Process.run('ditto', [
      '-c',
      '-k',
      '--sequesterRsrc',
      '--keepParent',
      payload,
      ipa,
    ]);
    if (archive.exitCode != 0) {
      stderr.write(archive.stderr);
      return archive.exitCode;
    }
    stdout.writeln('Unsigned IPA: $ipa');
    return 0;
  } finally {
    await tempDir.delete(recursive: true);
  }
}

Future<int> _adHocSign(String path, {String? entitlements}) async {
  final result = await Process.run('codesign', [
    '--force',
    '--sign',
    '-',
    '--timestamp=none',
    if (entitlements != null) ...[
      '--generate-entitlement-der',
      '--entitlements',
      entitlements,
    ],
    path,
  ]);
  if (result.exitCode != 0) {
    stderr
      ..write(result.stdout)
      ..write(result.stderr);
  }
  return result.exitCode;
}

typedef IOSSigningTarget = ({
  String bundle,
  String bundleIdentifier,
  String entitlements,
});

List<IOSSigningTarget> createIOSSigningTargets({
  required String rootDir,
  required String appPath,
  required String appBundleId,
}) {
  return [
    for (final name in const ['NECore', 'Widget', 'Runner'])
      (
        bundle: name == 'Runner'
            ? appPath
            : p.join(appPath, 'PlugIns', '$name.appex'),
        bundleIdentifier: name == 'Runner' ? appBundleId : '$appBundleId.$name',
        entitlements: p.join(rootDir, 'ios', name, '$name.entitlements'),
      ),
  ];
}

/// Resolves the build settings Xcode would expand. iOS refuses a Network
/// Extension whose signature names no application identifier, so a placeholder
/// team stands in until the bundle is signed for real.
String createIOSEntitlements({
  required String source,
  required String appBundleId,
  required String bundleIdentifier,
}) {
  const team = 'UNKNOWN000';
  final resolved = source.replaceAll(r'$(APP_BUNDLE_ID)', appBundleId);
  final end = resolved.lastIndexOf('</dict>');
  if (end < 0) {
    throw const FormatException('Entitlements plist is missing its dictionary');
  }
  return '${resolved.substring(0, end)}'
      '\t<key>application-identifier</key>\n'
      '\t<string>$team.$bundleIdentifier</string>\n'
      '\t<key>com.apple.developer.team-identifier</key>\n'
      '\t<string>$team</string>\n'
      '${resolved.substring(end)}';
}

String _detectArch() {
  if (Platform.isWindows) {
    final pa = Platform.environment['PROCESSOR_ARCHITECTURE'] ?? 'AMD64';
    return pa.toUpperCase() == 'ARM64' ? 'arm64' : 'amd64';
  }
  final result = Process.runSync('uname', ['-m']);
  final machine = (result.stdout as String).trim();
  if (machine == 'aarch64') return 'arm64';
  if (machine == 'x86_64') return 'amd64';
  return machine;
}

Future<bool> _hasCommand(String cmd) async {
  final which = Platform.isWindows ? 'where' : 'command';
  final args = Platform.isWindows ? [cmd] : ['-v', cmd];
  final result = await Process.run(which, args);
  return result.exitCode == 0;
}

Future<int> _ensureDependencies(String platform) async {
  switch (platform) {
    case 'macos':
      return _ensureMacosDependencies();
    case 'linux':
      return _ensureLinuxDependencies();
    default:
      return 0;
  }
}

Future<int> _ensureMacosDependencies() async {
  if (await _hasCommand('appdmg')) {
    stdout.writeln('appdmg already installed, skipping.');
    return 0;
  }
  stdout.writeln('Installing appdmg (DMG creator)...');
  final result = await Process.run('npm', ['install', '-g', 'appdmg']);
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
  }
  return result.exitCode;
}

Future<int> _ensureLinuxDependencies() async {
  const pkgGroups = <List<String>>[
    ['ninja-build', 'libgtk-3-dev'],
    ['libayatana-appindicator3-dev'],
    ['libsecret-1-dev'],
    ['locate'],
    ['rpm', 'patchelf'],
    ['libfuse2'],
  ];

  final missingGroups = <List<String>>[];
  for (final group in pkgGroups) {
    final missingPkgs = <String>[];
    for (final pkg in group) {
      if (!await _isDebianPackageInstalled(pkg)) {
        missingPkgs.add(pkg);
      }
    }
    if (missingPkgs.isNotEmpty) {
      missingGroups.add(missingPkgs);
    }
  }

  if (missingGroups.isEmpty) {
    stdout.writeln('All Linux build dependencies already installed, skipping.');
  } else {
    stdout.writeln('Updating apt package lists...');
    final updateExit = await _runLinuxDependencyCommand([
      'apt-get',
      'update',
      '-y',
    ]);
    if (updateExit != 0) {
      stderr.writeln(
        'apt-get update exited with $updateExit; continuing and verifying '
        'dependency installation directly.',
      );
    }

    for (final missingPkgs in missingGroups) {
      stdout.writeln(
        'Installing Linux build dependencies: ${missingPkgs.join(', ')}...',
      );
      final installExit = await _installLinuxPackages(missingPkgs);
      if (installExit != 0) return installExit;
    }
  }

  const appimagetool = '/usr/local/bin/appimagetool';
  if (File(appimagetool).existsSync()) {
    stdout.writeln('appimagetool already installed, skipping.');
    return 0;
  }
  stdout.writeln('Downloading appimagetool...');
  final downloadName =
      'appimagetool-${appImageToolArch(_detectArch())}.AppImage';
  final dlResult = await Process.run('wget', [
    '-O',
    appimagetool,
    'https://github.com/AppImage/AppImageKit/releases/download/continuous/$downloadName',
  ]);
  if (dlResult.exitCode != 0) {
    stderr.write(dlResult.stderr);
    return dlResult.exitCode;
  }
  await Process.run('chmod', ['+x', appimagetool]);
  return 0;
}

String appImageToolArch(String arch) {
  return arch == 'arm64' ? 'aarch64' : 'x86_64';
}

/// Ubuntu 24.04 ships libfuse2 under its time64 name, which `dpkg -s libfuse2` cannot see.
const _debianPackageAliases = <String, List<String>>{
  'libfuse2': ['libfuse2t64'],
};

Future<bool> _isDebianPackageInstalled(String pkg) async {
  for (final name in [pkg, ...?_debianPackageAliases[pkg]]) {
    final result = await Process.run('dpkg', ['-s', name]);
    if (result.exitCode == 0 &&
        (result.stdout as String).contains('Status: install ok installed')) {
      return true;
    }
  }
  return false;
}

Future<bool> _areDebianPackagesInstalled(List<String> pkgs) async {
  for (final pkg in pkgs) {
    if (!await _isDebianPackageInstalled(pkg)) {
      return false;
    }
  }
  return true;
}

Future<int> _installLinuxPackages(List<String> pkgs) async {
  final exitCode = await _runLinuxDependencyCommand([
    'apt-get',
    'install',
    '-y',
    ...pkgs,
  ]);
  if (exitCode == 0) return 0;

  if (await _areDebianPackagesInstalled(pkgs)) {
    stderr.writeln(
      'apt-get install exited with $exitCode, but all requested packages are '
      'installed; continuing.',
    );
    return 0;
  }

  return exitCode;
}

Future<int> _runLinuxDependencyCommand(List<String> command) async {
  final sudoCommand = [
    'env',
    'DEBIAN_FRONTEND=noninteractive',
    'NEEDRESTART_MODE=a',
    ...command,
  ];
  stdout.writeln('exec: sudo ${sudoCommand.join(' ')}');
  final result = await Process.start('sudo', sudoCommand);
  result.stdout.listen((data) {
    stdout.write(utf8.decode(data));
  });
  result.stderr.listen((data) {
    stderr.write(utf8.decode(data));
  });
  final exitCode = await result.exitCode;
  if (exitCode != 0) {
    stderr.writeln('Linux dependency command failed with exit code $exitCode.');
  }
  return exitCode;
}
