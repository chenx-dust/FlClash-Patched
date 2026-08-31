import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'build.dart';
import 'build_cache.dart';
import 'error.dart';
import 'fingerprint.dart';
import 'options.dart';
import 'target.dart';
import 'util.dart';

final _log = Logger('go_builder');

String _resolveGoLdflags(Target target, BuildConfig config) {
  if (target.goos != 'android' || !target.isLib) {
    return config.goLdflags;
  }
  return '${config.goLdflags} -extldflags -Wl,-z,max-page-size=16384';
}

String _resolveIosSdkPath() {
  final result = Process.runSync('xcrun', [
    '--sdk',
    'iphoneos',
    '--show-sdk-path',
  ]);
  if (result.exitCode != 0) {
    throw BuildException('Failed to locate iOS SDK: ${result.stderr}');
  }
  return (result.stdout as String).trim();
}

String resolveIosCgoFlags({
  required String sdkPath,
  required String arch,
  String baseFlags = '',
}) => [
  baseFlags.trim(),
  '-isysroot',
  sdkPath,
  '-miphoneos-version-min=14.0',
  '-arch',
  arch,
].where((value) => value.isNotEmpty).join(' ');

class GoBuilder {
  GoBuilder({
    required this.rootDir,
    required this.config,
    required this.cache,
    required this.notice,
    this.harnessInputs = const [],
    this.androidToolchain,
  });

  final String rootDir;
  final BuildConfig config;
  final BuildCache cache;
  final BuildNotice notice;
  final List<String> harnessInputs;
  final AndroidToolchain? androidToolchain;

  String get _corePath => p.join(rootDir, config.coreDir);
  String get _outputPath => p.join(rootDir, config.outputDir);

  String _resolveCc(Target target) {
    if (target.goos == 'ios') {
      return (runCommand('xcrun', [
                '--sdk',
                'iphoneos',
                '--find',
                'clang',
              ]).stdout
              as String)
          .trim();
    }
    final toolchain = androidToolchain;
    if (toolchain == null) {
      throw BuildException('Android target $target needs an NDK toolchain');
    }
    final cc = toolchain.clangFor(target);
    if (!File(cc).existsSync()) {
      throw BuildException(
        'NDK compiler not found: $cc (API ${toolchain.apiLevel} from the '
        'app minSdk; the NDK Flutter selected may be too old)',
      );
    }
    return cc;
  }

  Future<BuildExecution> build(Target target) async {
    final outDir = target.isLib
        ? p.join(_outputPath, target.platformDir, target.abi!)
        : p.join(_outputPath, target.platformDir);
    ensureDir(outDir);

    final fileName = target.isLib
        ? '${config.libName}${target.lowMemory ? '_lowmem' : ''}'
              '${target.dynamicLibExtension}'
        : '${config.coreName}${target.executableExtension}';
    final outFile = p.join(outDir, fileName);

    final variantKey = target.lowMemory ? '-lowmem' : '';
    return cache.run(
      key: '${target.platformDir}-${target.goarch}$variantKey-core',
      fingerprint: () => _calculateFingerprint(target),
      primaryOutput: outFile,
      notice: notice,
      build: () async {
        final env = _buildEnvironment(target);
        final buildMode = _buildMode(target);
        _log.info(
          'Building Go core: $target '
          '(${buildMode == null ? 'standalone' : 'CGO, $buildMode'})',
        );

        // A failed build must not destroy the previous artifacts.
        final stagingDir = Directory(
          p.join(outDir, '.staging-${target.goarch}-$pid'),
        );
        final staged = p.join(stagingDir.path, fileName);
        try {
          await runCommandStream(
            'go',
            _buildArguments(target, outFile: staged),
            workingDirectory: _corePath,
            environment: env,
          );

          final outputs = <String>[outFile];
          if (target.goos == 'android') {
            outputs.addAll(
              _installAndroidOutput(
                abi: target.abi!,
                platformDir: p.join(_outputPath, target.platformDir),
                stagingDir: stagingDir.path,
                libName: fileName,
                outFile: outFile,
              ),
            );
          } else {
            replaceFile(staged, outFile);
            if (target.goos == 'ios') {
              final headerName = '${p.basenameWithoutExtension(fileName)}.h';
              final header = p.join(outDir, headerName);
              replaceFile(p.join(stagingDir.path, headerName), header);
              outputs.add(header);
            }
          }

          _log.info('Built: $outFile');
          return outputs;
        } finally {
          if (stagingDir.existsSync()) {
            stagingDir.deleteSync(recursive: true);
          }
        }
      },
    );
  }

  Map<String, String> _buildEnvironment(Target target) {
    final env = <String, String>{'GOOS': target.goos, 'GOARCH': target.goarch};
    if (target.isLib) {
      env
        ..['CGO_ENABLED'] = '1'
        ..['CC'] = _resolveCc(target)
        ..['CGO_CFLAGS'] = '-O3 -Werror';
      if (target.goos == 'ios') {
        final sdkPath = _resolveIosSdkPath();
        env
          ..['CGO_CFLAGS'] = resolveIosCgoFlags(
            sdkPath: sdkPath,
            arch: target.goarch,
            baseFlags: env['CGO_CFLAGS'] ?? '',
          )
          ..['CGO_LDFLAGS'] = resolveIosCgoFlags(
            sdkPath: sdkPath,
            arch: target.goarch,
          );
      }
    } else {
      env['CGO_ENABLED'] = '0';
    }
    return env;
  }

  List<String> _buildArguments(Target target, {String? outFile}) {
    final buildMode = _buildMode(target);
    return [
      'build',
      '-ldflags=${_resolveGoLdflags(target, config)}',
      '-tags=${_buildTags(target)}',
      if (buildMode != null) '-buildmode=$buildMode',
      if (outFile != null) ...['-o', outFile],
    ];
  }

  String? _buildMode(Target target) {
    if (!target.isLib) return null;
    switch (target.goos) {
      case 'android':
        return 'c-shared';
      case 'ios':
        return 'c-archive';
      default:
        throw BuildException('Unsupported library target: ${target.goos}');
    }
  }

  String _buildTags(Target target) =>
      target.lowMemory ? '${config.tags} with_low_memory' : config.tags;

  Future<Fingerprint> _calculateFingerprint(Target target) async {
    final env = _buildEnvironment(target);
    final builder = FingerprintBuilder(rootDir: rootDir)
      ..addValue('cache_schema', BuildCache.schemaVersion)
      ..addValue('kind', 'go-core')
      ..addValue('target', {
        'goos': target.goos,
        'goarch': target.goarch,
        'abi': target.abi,
        'is_lib': target.isLib,
        'low_memory': target.lowMemory,
      })
      ..addValue('config', config.toFingerprintMap())
      ..addValue('environment', env)
      ..addValue('arguments', _buildArguments(target));

    final goEnvResult = runCommand(
      'go',
      [
        'env',
        '-json',
        'GOVERSION',
        'GOTOOLCHAIN',
        'GOFLAGS',
        'GOEXPERIMENT',
        'GOAMD64',
        'GOARM',
        'GO386',
        'GOMIPS',
        'GOMIPS64',
        'CGO_CFLAGS',
        'CGO_CPPFLAGS',
        'CGO_CXXFLAGS',
        'CGO_LDFLAGS',
        'GOWORK',
        'GOENV',
      ],
      workingDirectory: _corePath,
      environment: env,
    );
    final goEnv = jsonDecode((goEnvResult.stdout as String).trim());
    builder.addValue('go_env', goEnv);

    final inputs = _resolveGoInputs(env, target);
    final goWork = (goEnv as Map<String, dynamic>)['GOWORK'];
    if (goWork is String && goWork.isNotEmpty && goWork != 'off') {
      inputs.add(goWork);
      final goWorkSum = p.join(p.dirname(goWork), 'go.work.sum');
      if (File(goWorkSum).existsSync()) inputs.add(goWorkSum);
    }
    inputs.addAll(harnessInputs);

    if (target.isLib) {
      final compilerVersion = runCommand(env['CC']!, ['--version']);
      builder.addValue(
        target.goos == 'ios' ? 'ios_compiler' : 'android_compiler',
        '${(compilerVersion.stdout as String).trim()}\n'
        '${(compilerVersion.stderr as String).trim()}',
      );
    }

    builder.addFiles(inputs);
    return builder.finishWithInputs();
  }

  Set<String> _resolveGoInputs(Map<String, String> environment, Target target) {
    const template =
        r'''{{range .GoFiles}}{{$.Dir}}/{{.}}{{"\n"}}{{end}}{{range .CgoFiles}}{{$.Dir}}/{{.}}{{"\n"}}{{end}}{{range .CFiles}}{{$.Dir}}/{{.}}{{"\n"}}{{end}}{{range .CXXFiles}}{{$.Dir}}/{{.}}{{"\n"}}{{end}}{{range .MFiles}}{{$.Dir}}/{{.}}{{"\n"}}{{end}}{{range .HFiles}}{{$.Dir}}/{{.}}{{"\n"}}{{end}}{{range .FFiles}}{{$.Dir}}/{{.}}{{"\n"}}{{end}}{{range .SFiles}}{{$.Dir}}/{{.}}{{"\n"}}{{end}}{{range .SwigFiles}}{{$.Dir}}/{{.}}{{"\n"}}{{end}}{{range .SwigCXXFiles}}{{$.Dir}}/{{.}}{{"\n"}}{{end}}{{range .SysoFiles}}{{$.Dir}}/{{.}}{{"\n"}}{{end}}{{range .EmbedFiles}}{{$.Dir}}/{{.}}{{"\n"}}{{end}}{{with .Module}}{{if .GoMod}}{{.GoMod}}{{"\n"}}{{end}}{{end}}''';
    final result = runCommand(
      'go',
      ['list', '-deps', '-tags=${_buildTags(target)}', '-f', template, '.'],
      workingDirectory: _corePath,
      environment: environment,
    );
    final corePath = p.normalize(p.absolute(_corePath));
    final inputs = <String>{};
    for (final line in (result.stdout as String).split('\n')) {
      final value = line.trim();
      if (value.isEmpty) continue;
      final filePath = p.normalize(
        p.absolute(p.isAbsolute(value) ? value : p.join(_corePath, value)),
      );
      if (!p.isWithin(corePath, filePath) && !p.equals(corePath, filePath)) {
        continue;
      }
      if (!File(filePath).existsSync()) continue;
      inputs.add(filePath);
      if (p.basename(filePath) == 'go.mod') {
        final goSum = p.join(p.dirname(filePath), 'go.sum');
        if (File(goSum).existsSync()) inputs.add(goSum);
      }
    }

    for (final name in const ['go.mod', 'go.sum']) {
      final filePath = p.join(_corePath, name);
      if (File(filePath).existsSync()) inputs.add(filePath);
    }
    return inputs;
  }

  List<String> _installAndroidOutput({
    required String abi,
    required String platformDir,
    required String stagingDir,
    required String libName,
    required String outFile,
  }) {
    final includesPath = p.join(platformDir, 'includes', abi);
    final androidCoreMainPath = p.join(
      rootDir,
      'android',
      'core',
      'src',
      'main',
    );
    final jniLibsPath = p.join(androidCoreMainPath, 'jniLibs', abi);
    final cppIncludesPath = p.join(androidCoreMainPath, 'cpp', 'includes', abi);
    final outputs = <String>[];

    ensureDir(includesPath);
    _clearDirectory(includesPath);
    ensureDir(cppIncludesPath);
    _clearDirectory(cppIncludesPath);

    replaceFile(p.join(stagingDir, libName), outFile);
    copyFile(outFile, p.join(jniLibsPath, libName));
    outputs.add(p.join(jniLibsPath, libName));

    final generatedHeaders = Directory(stagingDir).listSync();
    final staticHeaders = Directory(_corePath).listSync();
    for (final file in [...generatedHeaders, ...staticHeaders]) {
      if (!file.path.endsWith('.h')) continue;
      final headerName = p.basename(file.path);
      final includePath = p.join(includesPath, headerName);
      final cppIncludePath = p.join(cppIncludesPath, headerName);
      copyFile(file.path, includePath);
      copyFile(file.path, cppIncludePath);
      outputs
        ..add(includePath)
        ..add(cppIncludePath);
    }
    return outputs;
  }

  void _clearDirectory(String dirPath) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return;

    for (final entity in dir.listSync()) {
      if (entity is File || entity is Link) {
        entity.deleteSync();
      } else if (entity is Directory) {
        entity.deleteSync(recursive: true);
      }
    }
  }
}
