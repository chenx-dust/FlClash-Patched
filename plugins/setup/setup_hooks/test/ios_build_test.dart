import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:setup_hooks/src/error.dart';
import 'package:setup_hooks/src/ios_build.dart';
import 'package:setup_hooks/src/target.dart';
import 'package:test/test.dart';

void main() {
  final rootDir = p.normalize(p.absolute('..', '..', '..'));
  final environment = {
    'SRCROOT': p.join(rootDir, 'ios'),
    'PLATFORM_NAME': 'iphoneos',
    'ARCHS': 'arm64',
  };

  test('Xcode shares the hook target, repository and fingerprint inputs', () {
    final request = iosBuildRequest(environment);
    expect(request.rootDir, rootDir);
    expect(request.target, Target.iosArm64);
    expect(
      request.harnessDir,
      p.join(rootDir, 'plugins', 'setup', 'setup_hooks'),
    );
  });

  test('rejects simulator builds including arm64 simulators', () {
    expect(
      () =>
          iosBuildRequest({...environment, 'PLATFORM_NAME': 'iphonesimulator'}),
      throwsA(isA<BuildException>()),
    );
  });

  test('rejects unsupported architecture slices', () {
    for (final architectures in ['x86_64', 'arm64 x86_64', '']) {
      expect(
        () => iosBuildRequest({...environment, 'ARCHS': architectures}),
        throwsA(isA<BuildException>()),
      );
    }
  });

  test('requires the Xcode source root', () {
    expect(
      () => iosBuildRequest({...environment}..remove('SRCROOT')),
      throwsA(isA<BuildException>()),
    );
  });

  test('NECore generates archives and headers before compiling sources', () {
    final project = File(
      p.join(rootDir, 'ios', 'Runner.xcodeproj', 'project.pbxproj'),
    ).readAsStringSync();
    final target = RegExp(
      r'/\* NECore \*/ = \{\s+isa = PBXNativeTarget;.*?buildPhases = \((.*?)\);',
      dotAll: true,
    ).firstMatch(project)!.group(1)!;
    expect(
      target.indexOf('/* Build iOS Core */'),
      allOf(isNonNegative, lessThan(target.indexOf('/* Sources */'))),
    );
    final configurations = RegExp(
      r'baseConfigurationReference = [^;]+/\* NECore.xcconfig \*/;'
      r'.*?ENABLE_USER_SCRIPT_SANDBOXING = (YES|NO);',
      dotAll: true,
    ).allMatches(project);
    expect(configurations.map((match) => match.group(1)), ['NO', 'NO', 'NO']);
  });
}
