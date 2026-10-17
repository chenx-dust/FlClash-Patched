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
      extraCargoEnvironmentVariables: _bindgenEnvironment(input),
    ).run(input: input, output: output);
  });
}

// rquickjs runs bindgen on Android, which must load the NDK's libclang; Linux
// NDKs before r26 keep it under lib64, later ones and every macOS NDK under lib.
Map<String, String> _bindgenEnvironment(BuildInput input) {
  if (!input.config.buildCodeAssets) {
    return const {};
  }
  if (input.config.code.targetOS == OS.iOS) {
    return _iOSBindgenEnvironment(input.config.code);
  }
  if (input.config.code.targetOS != OS.android) {
    return const {};
  }
  final compiler = input.config.code.cCompiler?.compiler;
  if (compiler == null) {
    return const {};
  }
  final llvmRoot = File.fromUri(compiler).parent.parent;
  for (final name in const ['lib', 'lib64']) {
    final directory = Directory(
      '${llvmRoot.path}${Platform.pathSeparator}$name',
    );
    if (directory.existsSync() && directory.listSync().any(_isLibclang)) {
      return {'LIBCLANG_PATH': directory.path};
    }
  }
  throw StateError(
    'No libclang under ${llvmRoot.path} (lib or lib64); the NDK Flutter '
    'passed cannot run bindgen for rquickjs',
  );
}

bool _isLibclang(FileSystemEntity entity) {
  return entity.path.split(Platform.pathSeparator).last.startsWith('libclang.');
}

Map<String, String> _iOSBindgenEnvironment(CodeConfig code) {
  final sdk = code.iOS.targetSdk == IOSSdk.iPhoneOS
      ? 'iphoneos'
      : 'iphonesimulator';
  String xcrun(List<String> arguments) {
    final result = Process.runSync('xcrun', ['--sdk', sdk, ...arguments]);
    if (result.exitCode != 0) {
      throw ProcessException(
        'xcrun',
        arguments,
        '${result.stderr}',
        result.exitCode,
      );
    }
    return (result.stdout as String).trim();
  }

  final clang = File(xcrun(['--find', 'clang']));
  return {
    // Rust stripping can misalign Mach-O LINKEDIT (rust-lang/rust#157750).
    'CARGO_PROFILE_RELEASE_STRIP': 'none',
    'LIBCLANG_PATH': '${clang.parent.parent.path}/lib',
    'BINDGEN_EXTRA_CLANG_ARGS': '-isysroot "${xcrun(['--show-sdk-path'])}"',
    'IPHONEOS_DEPLOYMENT_TARGET': '${code.iOS.targetVersion}.0',
  };
}
