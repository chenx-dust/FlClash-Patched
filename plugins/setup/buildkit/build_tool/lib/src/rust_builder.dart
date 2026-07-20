import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'build_cache.dart';
import 'fingerprint.dart';
import 'logging.dart';
import 'options.dart';
import 'target.dart';
import 'util.dart';

final _log = Logger('rust_builder');

class RustBuilder {
  final String rootDir;
  final BuildConfig config;
  final BuildCache cache;
  final BuildNotice notice;

  RustBuilder({
    required this.rootDir,
    required this.config,
    required this.cache,
    required this.notice,
  });

  String get _helperPath => p.join(rootDir, config.helperDir);
  String get _outputPath => p.join(rootDir, config.outputDir);

  Future<BuildExecution> build(
    Target target,
    String token, {
    bool release = true,
    bool force = false,
    Future<void> Function()? beforeBuild,
  }) async {
    final args = ['build'];
    if (release) {
      args.addAll(['--release', '--features', 'windows-service']);
    }
    final env = {
      'TOKEN': token,
      'CORE_EXECUTABLE_NAME': '${config.coreName}${target.executableExtension}',
    };

    final srcPath = p.join(
      _helperPath,
      'target',
      release ? 'release' : 'debug',
      'helper${target.executableExtension}',
    );
    final destDir = p.join(_outputPath, target.goos);
    final destPath = p.join(
      destDir,
      '${config.helperName}${target.executableExtension}',
    );
    return cache.run(
      key: '${target.goos}-${target.goarch}-helper-'
          '${release ? 'release' : 'debug'}',
      fingerprint: () => _calculateFingerprint(
        target: target,
        token: token,
        release: release,
        args: args,
      ),
      primaryOutput: destPath,
      force: force,
      notice: notice,
      build: () async {
        await beforeBuild?.call();
        _log.info(kDoubleSeparator);
        _log.info('Building Rust helper: $target');
        _log.info(kSeparator);

        await runCommandStream(
          'cargo',
          args,
          workingDirectory: _helperPath,
          environment: env,
        );

        ensureDir(destDir);
        copyFile(srcPath, destPath);

        _log.info('Built: $destPath');
        return [destPath];
      },
    );
  }

  Future<String> _calculateFingerprint({
    required Target target,
    required String token,
    required bool release,
    required List<String> args,
  }) async {
    final builder = FingerprintBuilder(rootDir: rootDir)
      ..addValue('cache_schema', BuildCache.schemaVersion)
      ..addValue('kind', 'windows-helper')
      ..addValue('target', {
        'goos': target.goos,
        'goarch': target.goarch,
      })
      ..addValue('release', release)
      ..addValue('arguments', args)
      ..addValue('token', token)
      ..addValue('environment', _rustEnvironment())
      ..addValue('config', config.toFingerprintMap());

    final cargoVersion = runCommand(
      'cargo',
      ['--version'],
      workingDirectory: _helperPath,
    );
    builder.addValue('cargo_version', (cargoVersion.stdout as String).trim());
    final rustVersion = runCommand(
      'rustc',
      ['-Vv'],
      workingDirectory: _helperPath,
    );
    builder.addValue('rustc_version', (rustVersion.stdout as String).trim());

    final inputs = collectFiles(
      _helperPath,
      excludedDirectories: const {'target', '.git', '.idea'},
    )..addAll(collectBuildToolInputs(rootDir));
    builder.addFiles(inputs);
    return builder.finish();
  }

  Map<String, String> _rustEnvironment() {
    const exactKeys = {
      'CARGO_BUILD_TARGET',
      'CARGO_ENCODED_RUSTFLAGS',
      'RUSTFLAGS',
      'RUSTUP_TOOLCHAIN',
      'RUSTC_WRAPPER',
      'RUSTC_WORKSPACE_WRAPPER',
    };
    final values = <String, String>{};
    final entries = Platform.environment.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final entry in entries) {
      if (exactKeys.contains(entry.key) ||
          entry.key.startsWith('CARGO_PROFILE_') ||
          entry.key.startsWith('CARGO_TARGET_')) {
        values[entry.key] = entry.value;
      }
    }
    return values;
  }
}
