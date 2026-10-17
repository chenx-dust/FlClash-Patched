import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:setup_hooks/src/error.dart';
import 'package:setup_hooks/src/target.dart';
import 'package:test/test.dart';

void main() {
  group('resolve', () {
    test('finds the target for a platform and GOARCH', () {
      expect(
        Target.resolve(platform: 'linux', goarch: 'arm64'),
        Target.linuxArm64,
      );
      expect(
        Target.resolve(platform: 'macos', goarch: 'arm64'),
        Target.macosArm64,
      );
      expect(
        Target.resolve(platform: 'windows', goarch: 'amd64'),
        Target.windowsAmd64,
      );
    });

    test('rejects a GOARCH or platform without a Core', () {
      expect(
        () => Target.resolve(platform: 'linux', goarch: 'riscv64'),
        throwsA(isA<BuildException>()),
      );
      expect(
        () => Target.resolve(platform: 'ios', goarch: 'arm64'),
        throwsA(isA<BuildException>()),
      );
    });
  });

  test('only Linux and Windows ship the Helper', () {
    expect(Target.all.where((target) => target.hasHelper), [
      Target.linuxArm64,
      Target.linuxAmd64,
      Target.windowsAmd64,
      Target.windowsArm64,
    ]);
  });

  test('names the Rust target triple for Helper platforms', () {
    expect(Target.windowsAmd64.rustTriple, 'x86_64-pc-windows-msvc');
    expect(Target.linuxArm64.rustTriple, 'aarch64-unknown-linux-gnu');
    expect(() => Target.macosArm64.rustTriple, throwsA(isA<BuildException>()));
  });

  test('names the Rust target triple for iOS devices and simulators', () {
    CodeConfig iosConfig(IOSSdk targetSdk) {
      final root = Directory.current.uri;
      final builder = BuildInputBuilder()
        ..setupShared(
          packageRoot: root,
          packageName: 'rust_api',
          outputDirectoryShared: root,
          outputFile: root.resolve('output.json'),
        )
        ..setupBuildInput()
        ..config.setupBuild(linkingEnabled: false);
      CodeAssetExtension(
        targetArchitecture: Architecture.arm64,
        targetOS: OS.iOS,
        linkModePreference: LinkModePreference.dynamic,
        iOS: IOSCodeConfig(targetSdk: targetSdk, targetVersion: 15),
      ).setupBuildInput(builder);
      return builder.build().config.code;
    }

    expect(rustTargetTriple(iosConfig(IOSSdk.iPhoneOS)), 'aarch64-apple-ios');
    expect(
      rustTargetTriple(iosConfig(IOSSdk.iPhoneSimulator)),
      'aarch64-apple-ios-sim',
    );
  });
}
