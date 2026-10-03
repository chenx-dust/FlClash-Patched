import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:flutter_rust_bridge_hooks/flutter_rust_bridge_hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (input.userDefines['build_assets'] == false) {
      stdout.writeln('Skipping the Rust build: user-define build_assets=false');
      return;
    }
    await FlutterRustBridgeNativeAssetsBuilder(
      cratePath: 'rust',
      extraCargoEnvironmentVariables: _cargoEnvironment(input),
    ).run(input: input, output: output);
  });
}

// rquickjs runs bindgen on Android, which must load the NDK's libclang; Linux
// NDKs before r26 keep it under lib64, later ones and every macOS NDK under lib.
Map<String, String> _cargoEnvironment(BuildInput input) {
  if (!input.config.buildCodeAssets) return const {};
  final code = input.config.code;
  final environment = {
    // Rust stripping can misalign Mach-O LINKEDIT (rust-lang/rust#157750).
    if (code.targetOS == OS.macOS || code.targetOS == OS.iOS)
      'CARGO_PROFILE_RELEASE_STRIP': 'none',
  };
  if (code.targetOS == OS.iOS) {
    final sdk = code.iOS.targetSdk == IOSSdk.iPhoneOS
        ? 'iphoneos'
        : 'iphonesimulator';
    String xcrun(List<String> args) {
      final result = Process.runSync('xcrun', ['--sdk', sdk, ...args]);
      if (result.exitCode != 0) {
        throw ProcessException(
          'xcrun',
          args,
          '${result.stderr}',
          result.exitCode,
        );
      }
      return (result.stdout as String).trim();
    }

    final sdkPath = xcrun(['--show-sdk-path']);
    final clang = xcrun(['--find', 'clang']);
    return {
      ...environment,
      'LIBCLANG_PATH': '${File(clang).parent.parent.path}/lib',
      'BINDGEN_EXTRA_CLANG_ARGS': '-isysroot "$sdkPath"',
      'IPHONEOS_DEPLOYMENT_TARGET': '${code.iOS.targetVersion}.0',
    };
  }
  if (code.targetOS != OS.android) {
    return environment;
  }
  final compiler = input.config.code.cCompiler?.compiler;
  if (compiler == null) {
    return const {};
  }
  final llvmRoot = File.fromUri(compiler).parent.parent;
  for (final name in const ['lib', 'lib64', 'bin']) {
    final directory = Directory(
      '${llvmRoot.path}${Platform.pathSeparator}$name',
    );
    if (directory.existsSync() && directory.listSync().any(_isLibclang)) {
      return {
        'LIBCLANG_PATH': directory.path,
        _androidBindgenClangArgsKey(code): _androidBindgenClangArgs(
          llvmRoot,
          code,
        ),
        if (Platform.isWindows)
          'PATH': '${llvmRoot.path}\\bin;${Platform.environment['PATH'] ?? ''}',
      };
    }
  }
  throw StateError(
    'No libclang under ${llvmRoot.path} (lib, lib64, or bin); the NDK Flutter '
    'passed cannot run bindgen for rquickjs',
  );
}

bool _isLibclang(FileSystemEntity entity) {
  return entity.path.split(Platform.pathSeparator).last.startsWith('libclang.');
}

String _androidBindgenClangArgsKey(CodeConfig code) {
  final triple = _androidRustTriple(
    code.targetArchitecture,
  ).replaceAll('-', '_');
  return 'BINDGEN_EXTRA_CLANG_ARGS_$triple';
}

// NDK r30 rejects bindgen's unversioned Rust triple; the suffixed variable native_toolchain_rust sets (sysroot only) overrides BINDGEN_EXTRA_CLANG_ARGS.
String _androidBindgenClangArgs(Directory llvmRoot, CodeConfig code) {
  final architecture = code.targetArchitecture;
  final rustTriple = _androidRustTriple(architecture);
  final clangTriple = architecture == Architecture.arm
      ? 'armv7a-linux-androideabi'
      : rustTriple;
  final includeTriple = architecture == Architecture.arm
      ? 'arm-linux-androideabi'
      : rustTriple;
  final sysroot = '${llvmRoot.path}/sysroot'.replaceAll(r'\', '/');
  final api = code.android.targetNdkApi;
  return '--target=$clangTriple$api --sysroot=$sysroot '
      '-I$sysroot/usr/include/$includeTriple';
}

String _androidRustTriple(Architecture architecture) {
  return switch (architecture) {
    Architecture.arm64 => 'aarch64-linux-android',
    Architecture.arm => 'armv7-linux-androideabi',
    Architecture.x64 => 'x86_64-linux-android',
    _ => throw StateError('No Android Rust triple for $architecture'),
  };
}
